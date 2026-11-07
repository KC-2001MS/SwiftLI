//
//  State.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2024/05/27.
//

import Foundation

// MARK: - @State macro

/// Declares a property whose value is managed by SwiftLI and whose changes
/// re-render the view hierarchy that reads it.
///
/// Use `@State` inside a ``View`` or a ``Command`` to declare values that
/// change over time. When the value changes, the runtime re-evaluates `body`
/// and redraws the terminal output — just like SwiftUI:
///
/// ```swift
/// struct Counter: View {
///     @State private var count = 0
///
///     var body: some View {
///         Button("Tapped \(count) times") { count += 1 }
///     }
/// }
/// ```
///
/// Use the `$` prefix to obtain a ``Binding`` to the value:
///
/// ```swift
/// Slider(value: $volume, in: 0...100)
/// ```
///
/// `@State` is a macro, as in SwiftUI since Xcode 27. The expansion stores the
/// value in a lazily created, identity-aware storage: a view inside a
/// re-evaluated body keeps the same state from frame to frame, and the initial
/// value is computed only when the state is first read. The underlying
/// ``State`` property-wrapper type remains available for code that
/// constructs it directly (`State(wrappedValue:)`), and `_x` / `$x` keep their
/// property-wrapper meaning.
@attached(accessor, names: named(init), named(get), named(set))
@attached(peer, names: suffixed(__storage), prefixed(`_`), prefixed(`$`))
public macro State() = #externalMacro(module: "SwiftLIMacros", type: "StateMacro")

/// Declares a state property whose initial value is given in the attribute:
/// `@State(initialValue: 0) var count: Int`.
@attached(accessor, names: named(init), named(get), named(set))
@attached(peer, names: suffixed(__storage), prefixed(`_`), prefixed(`$`))
public macro State<Value>(initialValue: Value) = #externalMacro(module: "SwiftLIMacros", type: "StateMacro")

/// Declares a state property whose initial value is given in the attribute:
/// `@State(wrappedValue: 0) var count: Int`.
@attached(accessor, names: named(init), named(get), named(set))
@attached(peer, names: suffixed(__storage), prefixed(`_`), prefixed(`$`))
public macro State<Value>(wrappedValue: Value) = #externalMacro(module: "SwiftLIMacros", type: "StateMacro")

/// Implementation detail of the ``State()`` macro: gives the generated `_x`
/// peer its accessors. Do not apply directly.
@attached(accessor, names: named(get), named(set))
public macro _StateStorageAccessor() = #externalMacro(module: "SwiftLIMacros", type: "StateStorageAccessorMacro")

/// Implementation detail of the ``State()`` macro: gives the generated `$x`
/// peer its accessor. Do not apply directly.
@attached(accessor, names: named(get))
public macro _StateProjectedValue() = #externalMacro(module: "SwiftLIMacros", type: "StateProjectedValueMacro")

// MARK: - State

/// The storage behind a `@State` property: holds a mutable value and triggers
/// re-rendering when the value changes.
///
/// `@State` (the macro) expands to this type; use the type directly only when
/// you need to construct state in an initializer:
///
/// ```swift
/// init(start: Int) {
///     _count = State(wrappedValue: start)
/// }
/// ```
///
/// The value lives in a reference-type box shared by every copy of the
/// enclosing struct, so a `nonmutating set` can update it. The box is
/// resolved on first access: inside a rendering session it asks the render
/// pass for the storage that belongs to this view's position and this
/// property, so a child view keeps its state across the frames in which its
/// parent's body is re-evaluated; outside a session (and for a `Command`,
/// whose instance lives for the whole run) the box simply holds the value.
@propertyWrapper
public struct State<Value: Sendable>: Sendable {
    private let box: StateBox<Value>

    /// Creates a state property with an initial value.
    /// - Parameter wrappedValue: The initial value of the state.
    public init(wrappedValue: Value) {
        self.box = StateBox(storage: StateStorage(value: wrappedValue))
    }

    /// Creates a state property with an initial value.
    /// - Parameter initialValue: The initial value of the state.
    public init(initialValue: Value) {
        self.init(wrappedValue: initialValue)
    }

    private init(box: StateBox<Value>) {
        self.box = box
    }

    /// The current value of the state.
    ///
    /// Reading returns the latest value. Writing stores the new value and
    /// notifies all registered observers (``AppRuntime`` and any active
    /// ``InlineCommand``/``FullScreenCommand``).
    public var wrappedValue: Value {
        get { box.storage.value }
        nonmutating set {
            box.storage.value = newValue
            Self.notifyChange()
        }
    }

    /// A binding to the state value.
    ///
    /// Use the `$` prefix on a `@State` property to get a ``Binding`` that
    /// enables two-way data flow. Setting the binding also triggers observers.
    public var projectedValue: Binding<Value> {
        let box = box
        return Binding(
            get: { box.storage.value },
            set: { newValue in
                box.storage.value = newValue
                Self.notifyChange()
            }
        )
    }

    private static func notifyChange() {
        // Notify the full-screen CLIApp runtime (if active)
        AppRuntime.shared?.scheduleRender()
        // Notify any inline command renderer (if active)
        StateObserverRegistry.shared.notifyChange()
    }

    // MARK: Macro support

    /// Creates the storage behind a `@State` property whose initial value is
    /// computed lazily.
    ///
    /// Used by the ``State()`` macro expansion; `named` is the property's name,
    /// which (with the view's position in the render tree) identifies the
    /// state across frames.
    public static func _makeStorage(named name: StaticString, initialValue: @escaping @Sendable () -> Value) -> State<Value> {
        State(box: StateBox(name: name, initialValue: initialValue))
    }

    /// Creates the storage behind a `@State` property from an explicit
    /// initial value (the memberwise-initializer path of the macro expansion).
    public static func _makeStorage(named name: StaticString, initialValue: Value) -> State<Value> {
        State(box: StateBox(name: name, initialValue: { initialValue }))
    }
}

// MARK: - Decodable conformance

extension State: Decodable where Value: Decodable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(Value.self)
        self.init(wrappedValue: value)
    }
}

// MARK: - StateBox

/// The reference every copy of a `@State` shares: resolves its
/// ``StateStorage`` on first use.
///
/// A box made by the ``State()`` macro carries the property's name and an
/// initial-value closure. When first read during a render pass that keeps a
/// ``RetainedTree``, it asks the tree for the storage registered under the
/// current view identity and that name — the storage the previous frame
/// used — and only creates a fresh one when none exists. Read outside such a
/// pass it creates its own storage and keeps it, which is what a `Command`
/// (one instance for the whole run) or a one-shot `render()` needs.
final class StateBox<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var resolved: StateStorage<Value>?
    private let name: StaticString?
    private var initialValue: (@Sendable () -> Value)?

    init(storage: StateStorage<Value>) {
        resolved = storage
        name = nil
        initialValue = nil
    }

    init(name: StaticString, initialValue: @escaping @Sendable () -> Value) {
        resolved = nil
        self.name = name
        self.initialValue = initialValue
    }

    var storage: StateStorage<Value> {
        lock.lock()
        defer { lock.unlock() }
        if let resolved { return resolved }
        guard let initialValue else {
            preconditionFailure("@State storage has no initial value")
        }
        let storage: StateStorage<Value>
        if let name, let pass = RenderPassContext.current, let tree = pass.retained {
            storage = tree.stateStorage(at: pass.identity, name: name.description) {
                StateStorage(value: initialValue())
            }
        } else {
            storage = StateStorage(value: initialValue())
        }
        resolved = storage
        self.initialValue = nil
        return storage
    }
}

// MARK: - StateStorage

/// Thread-safe mutable storage for a ``State`` value.
///
/// Using a class (reference type) allows the `nonmutating set` on
/// `State.wrappedValue` to mutate the stored value without requiring
/// the enclosing struct to be `mutating`.
final class StateStorage<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: Value

    init(value: Value) {
        self._value = value
    }

    var value: Value {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _value
        }
        set {
            lock.lock()
            _value = newValue
            lock.unlock()
        }
    }
}

// MARK: - StateObserverRegistry

/// A global registry that routes ``State`` change notifications to a currently
/// active ``InlineCommand`` renderer.
///
/// Only one observer may be active at a time — the currently running
/// `InlineCommand`/`FullScreenCommand`. It is registered by ``InlineCommand/startBodyRendering()``
/// and unregistered by ``InlineCommand/stopBodyRendering()``.
final class StateObserverRegistry: @unchecked Sendable {
    static let shared = StateObserverRegistry()

    private let lock = NSLock()
    private var observer: (() -> Void)?
    // While > 0, `notifyChange()` records that a render is owed instead of
    // firing immediately — see `batch(_:)`.
    private var batchDepth = 0
    private var missedChangeWhileBatching = false

    private init() {}

    /// Registers a callback to be invoked on every state change.
    func register(_ callback: @escaping () -> Void) {
        lock.lock()
        observer = callback
        lock.unlock()
    }

    /// Removes the currently registered callback.
    func unregister() {
        lock.lock()
        observer = nil
        lock.unlock()
    }

    /// Invokes the registered callback, if any — immediately, unless a
    /// `batch(_:)` is in progress, in which case the render is deferred to
    /// its end.
    func notifyChange() {
        lock.lock()
        guard batchDepth == 0 else {
            missedChangeWhileBatching = true
            lock.unlock()
            return
        }
        let cb = observer
        lock.unlock()
        cb?()
    }

    /// Runs `body` with rendering suppressed, then renders at most once
    /// afterward if any change occurred during it.
    ///
    /// `FullScreenCommand`'s render-on-change is synchronous and uncoalesced
    /// (unlike `AppRuntime`'s, which already debounces via
    /// `DispatchQueue.main.async`): every `@State`/`Binding` write renders
    /// immediately. A burst of key events decoded from one `read()` — e.g.
    /// every character an IME committed at once — would otherwise apply and
    /// redraw one character at a time, visibly stepping through partial
    /// states instead of updating atomically. Wrapping such a burst in
    /// `batch` lets every event's state change land before the one render
    /// that shows all of them together.
    func batch(_ body: () -> Void) {
        lock.lock()
        batchDepth += 1
        lock.unlock()

        body()

        lock.lock()
        batchDepth -= 1
        let shouldRender = batchDepth == 0 && missedChangeWhileBatching
        if shouldRender { missedChangeWhileBatching = false }
        let cb = observer
        lock.unlock()
        if shouldRender { cb?() }
    }
}
