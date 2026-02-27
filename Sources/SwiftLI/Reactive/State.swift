//
//  State.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2024/05/27.
//

import Foundation

/// A property wrapper that holds mutable state and triggers re-rendering
/// when the value changes.
///
/// Use `@State` inside a ``CLIApp`` or any ``View`` struct to declare values
/// that can change over time. When the value changes, the runtime automatically
/// re-evaluates `body` and re-renders the terminal output — just like SwiftUI.
///
/// ```swift
/// @main
/// struct MyApp: CLIApp {
///     @State var progress: Double = 0.0
///
///     var body: [View] {
///         Text("Progress: \(Int(progress * 100))%").newLine()
///     }
/// }
/// ```
///
/// When used inside a ``ViewableCommand``, state changes automatically redraw
/// the command's `body` in-place — no manual `updateBody()` call needed after
/// the initial `startBodyRendering()`.
///
/// Use the `$` prefix to obtain a ``Binding`` to the underlying value:
///
/// ```swift
/// ProgressBar(min: 0, value: $progress, max: 100)
/// ```
@propertyWrapper
public struct State<Value: Sendable>: Sendable {
    // The actual storage lives in a reference-type box so the property wrapper
    // (which resides inside a struct) can mutate through a shared reference.
    private let storage: StateStorage<Value>

    /// Creates a state property with an initial value.
    /// - Parameter wrappedValue: The initial value of the state.
    public init(wrappedValue: Value) {
        self.storage = StateStorage(value: wrappedValue)
    }

    /// The current value of the state.
    ///
    /// Reading returns the latest value. Writing stores the new value and
    /// notifies all registered observers (``AppRuntime`` and any active
    /// ``ViewableCommand``).
    public var wrappedValue: Value {
        get { storage.value }
        nonmutating set {
            storage.value = newValue
            // Notify the full-screen CLIApp runtime (if active)
            AppRuntime.shared?.scheduleRender()
            // Notify any ViewableCommand inline renderer (if active)
            StateObserverRegistry.shared.notifyChange()
        }
    }

    /// A binding to the state value.
    ///
    /// Use the `$` prefix on a `@State` property to get a ``Binding`` that
    /// enables two-way data flow. Setting the binding also triggers observers.
    public var projectedValue: Binding<Value> {
        Binding(
            get: { storage.value },
            set: { [storage] newValue in
                storage.value = newValue
                AppRuntime.shared?.scheduleRender()
                StateObserverRegistry.shared.notifyChange()
            }
        )
    }
}

// MARK: - Decodable conformance

extension State: Decodable where Value: Decodable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(Value.self)
        self.storage = StateStorage(value: value)
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
/// active ``ViewableCommand`` inline renderer.
///
/// Only one observer may be active at a time — the currently running
/// `ViewableCommand`. It is registered by ``ViewableCommand/startBodyRendering()``
/// and unregistered by ``ViewableCommand/stopBodyRendering()``.
final class StateObserverRegistry: @unchecked Sendable {
    static let shared = StateObserverRegistry()

    private let lock = NSLock()
    private var observer: (() -> Void)?

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

    /// Invokes the registered callback, if any.
    func notifyChange() {
        lock.lock()
        let cb = observer
        lock.unlock()
        cb?()
    }
}
