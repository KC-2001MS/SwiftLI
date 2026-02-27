//
//  Binding.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2024/05/27.
//

/// A two-way reference to a piece of mutable state.
///
/// `Binding` enables child views or components to read and write a value
/// owned by a parent without needing direct ownership. It mirrors SwiftUI's
/// `Binding` type for consistency.
///
/// You usually obtain a `Binding` from a `@State` property's projected
/// value (the `$` prefix):
///
/// ```swift
/// struct ContentView: View {
///     @State var count = 0
///
///     var body: [View] {
///         Text("Count: \(count)").newLine()
///     }
/// }
/// ```
///
/// You can also create a constant, non-mutable binding for testing:
///
/// ```swift
/// let binding = Binding.constant(0.5)
/// ```
public struct Binding<Value: Sendable>: Sendable {
    private let getValue: @Sendable () -> Value
    private let setValue: @Sendable (Value) -> Void

    /// Creates a binding with explicit get and set closures.
    /// - Parameters:
    ///   - get: A closure that returns the current value.
    ///   - set: A closure that accepts a new value and stores it.
    public init(
        get: @escaping @Sendable () -> Value,
        set: @escaping @Sendable (Value) -> Void
    ) {
        self.getValue = get
        self.setValue = set
    }

    /// The underlying value referenced by the binding.
    ///
    /// Reading this property returns the current value via the `get` closure.
    /// Writing this property forwards the new value to the `set` closure, which
    /// typically updates a `@State` variable and schedules a re-render.
    public var wrappedValue: Value {
        get { getValue() }
        nonmutating set { setValue(newValue) }
    }

    /// Creates a constant binding that always returns the given value and
    /// silently ignores any writes.
    ///
    /// - Parameter value: The immutable value to expose.
    /// - Returns: A `Binding` whose `wrappedValue` always equals `value`.
    public static func constant(_ value: Value) -> Binding<Value> {
        Binding(get: { value }, set: { _ in })
    }
}
