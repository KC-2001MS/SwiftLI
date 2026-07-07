//
//  FocusState.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/07.
//

import Foundation

/// A property wrapper that observes and controls which input control is
/// focused, mirroring SwiftUI's `@FocusState`.
///
/// Declare a `@FocusState` whose value identifies the focusable controls, then
/// bind each control with ``SwiftLI/View/focused(_:equals:)``:
///
/// ```swift
/// enum Field { case name, email }
/// @FocusState var field: Field?
///
/// var body: some View {
///     TextField("Name",  text: $name).focused($field, equals: .name)
///     TextField("Email", text: $email).focused($field, equals: .email)
/// }
/// ```
///
/// Reading `field` tells you which control is focused; writing it moves focus
/// there. Moving focus with <kbd>Tab</kbd> updates `field` too, so the binding
/// always reflects reality.
///
/// A `Bool`-valued `@FocusState` works with ``SwiftLI/View/focused(_:)`` for a
/// single control.
@propertyWrapper
public struct FocusState<Value: Hashable & Sendable>: Sendable {

    /// Thread-safe reference storage shared between the wrapper and its bindings.
    final class Box: @unchecked Sendable {
        private let lock = NSLock()
        private var _value: Value
        init(_ value: Value) { _value = value }
        var value: Value {
            get { lock.lock(); defer { lock.unlock() }; return _value }
            set { lock.lock(); _value = newValue; lock.unlock() }
        }
    }

    private let box: Box

    /// Creates a focus state that starts unfocused (`nil`).
    public init() where Value: ExpressibleByNilLiteral {
        self.box = Box(nil)
    }

    /// Creates a `Bool` focus state that starts unfocused (`false`).
    public init() where Value == Bool {
        self.box = Box(false)
    }

    /// Creates a focus state with an explicit initial value.
    public init(wrappedValue: Value) {
        self.box = Box(wrappedValue)
    }

    public var wrappedValue: Value {
        get { box.value }
        nonmutating set {
            box.value = newValue
            // Schedule a redraw asynchronously so a focus change made *during* a
            // layout pass (e.g. from Tab syncing back) never re-enters rendering.
            DispatchQueue.main.async {
                AppRuntime.shared?.scheduleRender()
                StateObserverRegistry.shared.notifyChange()
            }
        }
    }

    /// The binding passed to ``SwiftLI/View/focused(_:equals:)`` / `focused(_:)`.
    public var projectedValue: FocusState<Value>.Binding {
        Binding(box: box)
    }

    /// A two-way reference to a ``FocusState``'s value.
    public struct Binding: Sendable {
        let box: Box
        public var wrappedValue: Value {
            get { box.value }
            nonmutating set {
                box.value = newValue
                DispatchQueue.main.async {
                    AppRuntime.shared?.scheduleRender()
                    StateObserverRegistry.shared.notifyChange()
                }
            }
        }
    }
}

// MARK: - Decodable

// Lets a `@FocusState` sit in an `AsyncParsableCommand` (which synthesises
// `Decodable`). Focus is transient UI state, so it always starts unfocused
// regardless of the decoder — mirroring how `@State` participates in decoding.
extension FocusState: Decodable where Value: ExpressibleByNilLiteral {
    public init(from decoder: any Decoder) throws {
        self.init()
    }
}

// MARK: - .focused() modifiers

public extension View {
    /// Binds this control's focus to a `@FocusState` value.
    ///
    /// The control is focused when `binding` equals `value`; focusing it (via
    /// Tab or a click-through) writes `value` back into the binding.
    func focused<V: Hashable & Sendable>(_ binding: FocusState<V?>.Binding, equals value: V) -> FocusModifier {
        FocusModifier(
            content: self,
            onFocus: { if binding.wrappedValue != value { binding.wrappedValue = value } },
            onUnfocus: { if binding.wrappedValue == value { binding.wrappedValue = nil } },
            isRequested: { binding.wrappedValue == value }
        )
    }

    /// Binds this control's focus to a `Bool` `@FocusState`.
    func focused(_ binding: FocusState<Bool>.Binding) -> FocusModifier {
        FocusModifier(
            content: self,
            onFocus: { if !binding.wrappedValue { binding.wrappedValue = true } },
            onUnfocus: { if binding.wrappedValue { binding.wrappedValue = false } },
            isRequested: { binding.wrappedValue }
        )
    }
}

/// A transparent wrapper that ties the control it contains to a ``FocusState``.
///
/// Created by ``SwiftLI/View/focused(_:equals:)``. During layout it pushes its
/// focus callbacks onto ``FocusCoordinator`` so the control lowered inside picks
/// them up when it registers, then pops them.
public struct FocusModifier: View {
    let content: any View
    let onFocus: @Sendable () -> Void
    let onUnfocus: @Sendable () -> Void
    let isRequested: @Sendable () -> Bool

    public var body: some View { Group(contents: []) }

    @_spi(RenderingInternals)
    public func addHeader(_ header: String) -> FocusModifier {
        FocusModifier(content: content.addHeader(header), onFocus: onFocus, onUnfocus: onUnfocus, isRequested: isRequested)
    }

    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        FocusCoordinator.shared.pushFocus(onFocus: onFocus, onUnfocus: onUnfocus, isRequested: isRequested)
        let node = content.makeNode()
        FocusCoordinator.shared.popFocus()
        return node
    }
}
