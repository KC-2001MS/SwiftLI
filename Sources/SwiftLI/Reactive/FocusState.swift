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

    /// The currently focused control identifier, or `false`/`nil` when nothing is focused.
    ///
    /// Writing this value programmatically moves focus to the matching control and
    /// schedules a terminal redraw.
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
        /// The current focus value; writing moves focus and triggers a redraw.
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
    /// Creates an unfocused focus state, ignoring the decoder's contents.
    ///
    /// Focus is transient UI state and is never persisted, so decoding always
    /// produces an unfocused instance regardless of the encoded data.
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
    func focused<V: Hashable & Sendable>(_ binding: FocusState<V?>.Binding, equals value: V) -> some View {
        modifier(FocusBindingModifier(
            onFocus: { if binding.wrappedValue != value { binding.wrappedValue = value } },
            onUnfocus: { if binding.wrappedValue == value { binding.wrappedValue = nil } },
            isRequested: { binding.wrappedValue == value }
        ))
    }

    /// Binds this control's focus to a `Bool` `@FocusState`.
    func focused(_ binding: FocusState<Bool>.Binding) -> some View {
        modifier(FocusBindingModifier(
            onFocus: { if !binding.wrappedValue { binding.wrappedValue = true } },
            onUnfocus: { if binding.wrappedValue { binding.wrappedValue = false } },
            isRequested: { binding.wrappedValue }
        ))
    }
}

/// The modifier behind ``SwiftLI/View/focused(_:equals:)``: ties the control
/// it modifies to a ``FocusState``.
///
/// While the content lowers it pushes its focus callbacks onto
/// ``FocusCoordinator`` so the control lowered inside picks them up when it
/// registers, then pops them.
struct FocusBindingModifier: ViewModifier {
    let onFocus: @Sendable () -> Void
    let onUnfocus: @Sendable () -> Void
    let isRequested: @Sendable () -> Bool

    func node(for content: RenderNode) -> RenderNode {
        content
    }

    func node(lowering content: () -> RenderNode) -> RenderNode {
        FocusCoordinator.shared.pushFocus(onFocus: onFocus, onUnfocus: onUnfocus, isRequested: isRequested)
        defer { FocusCoordinator.shared.popFocus() }
        return content()
    }
}
