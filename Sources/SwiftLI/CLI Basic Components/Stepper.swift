//
//  Stepper.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/10.
//

/// A control that increments or decrements a value, composed of two
/// ``Button``s around the current value.
///
/// `Stepper` mirrors SwiftUI's `Stepper`, adapted to the terminal. It renders
/// as `label [-] value [+]`; the `[-]` and `[+]` are ordinary ``Button``s, so
/// <kbd>Tab</kbd> reaches each of them and <kbd>Return</kbd>/<kbd>Space</kbd>
/// steps the value.
///
/// ```swift
/// @State var quantity = 1
///
/// var body: some View {
///     Stepper("Quantity", value: $quantity, in: 1...10)
/// }
/// ```
///
/// For full control, provide the increment and decrement actions yourself:
///
/// ```swift
/// Stepper("Zoom", onIncrement: { zoom *= 2 }, onDecrement: { zoom /= 2 })
/// ```
public struct Stepper: View {
    let style: TextStyle
    let id: String
    let label: AnyView?
    /// Reads the current value's display text lazily, so a `Binding`-backed
    /// stepper always shows the latest value on re-render. `nil` shows none.
    let valueText: () -> String?
    let onIncrement: () -> Void
    let onDecrement: () -> Void

    /// Creates a stepper that invokes custom closures on each step.
    /// - Parameters:
    ///   - title: The text shown before the control; also the default identity.
    ///   - id: An explicit identity; defaults to the title.
    ///   - onIncrement: Called when the `[+]` button is activated.
    ///   - onDecrement: Called when the `[-]` button is activated.
    public init(
        _ title: LocalizedStringKey = "",
        id: String? = nil,
        onIncrement: @escaping () -> Void,
        onDecrement: @escaping () -> Void
    ) {
        let resolved = String(localized: title.localizationValue)
        self.style = .plain
        self.id = id ?? (resolved.isEmpty ? "Stepper" : resolved)
        self.label = resolved.isEmpty ? nil : AnyView(Text(content: resolved))
        self.valueText = { nil }
        self.onIncrement = onIncrement
        self.onDecrement = onDecrement
    }

    /// Creates a stepper bound to a value, stepping it within optional bounds.
    /// - Parameters:
    ///   - title: The text shown before the control; also the default identity.
    ///   - value: The bound value shown between the buttons.
    ///   - bounds: When given, steps are clamped to this range.
    ///   - step: The distance of one step. Defaults to `1`.
    ///   - id: An explicit identity; defaults to the title.
    public init<V: Strideable & CustomStringConvertible>(
        _ title: LocalizedStringKey = "",
        value: Binding<V>,
        in bounds: ClosedRange<V>? = nil,
        step: V.Stride = 1,
        id: String? = nil
    ) {
        let resolved = String(localized: title.localizationValue)
        self.style = .plain
        self.id = id ?? (resolved.isEmpty ? "Stepper" : resolved)
        self.label = resolved.isEmpty ? nil : AnyView(Text(content: resolved))
        self.valueText = { value.wrappedValue.description }

        func clamped(_ v: V) -> V {
            guard let bounds else { return v }
            return Swift.min(Swift.max(v, bounds.lowerBound), bounds.upperBound)
        }
        self.onIncrement = { value.wrappedValue = clamped(value.wrappedValue.advanced(by: step)) }
        self.onDecrement = { value.wrappedValue = clamped(value.wrappedValue.advanced(by: -step)) }
    }

    init(style: TextStyle, id: String, label: AnyView?, valueText: @escaping () -> String?, onIncrement: @escaping () -> Void, onDecrement: @escaping () -> Void) {
        self.style = style
        self.id = id
        self.label = label
        self.valueText = valueText
        self.onIncrement = onIncrement
        self.onDecrement = onDecrement
    }

    /// The content of the stepper view; rendering is handled by ``makeNode()``.
    public var body: some View {
        EmptyView()
    }

    @_spi(RenderingInternals)
    public func applyingStyle(_ style: TextStyle) -> Self {
        Stepper(style: self.style.inheriting(style), id: id, label: label, valueText: valueText, onIncrement: onIncrement, onDecrement: onDecrement)
    }

    /// Lowers to `label [-] value [+]` — the two brackets are plain-styled
    /// ``Button``s that register themselves in the focus ring as usual.
    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        var cells: [any View] = []
        if let label { cells.append(label) }
        cells.append(
            Button(id: "\(id).decrement", action: onDecrement) { Text(verbatim: "[-]") }
                .buttonStyle(PlainButtonStyle())
        )
        if let text = valueText() {
            cells.append(Text(verbatim: text).bold())
        }
        cells.append(
            Button(id: "\(id).increment", action: onIncrement) { Text(verbatim: "[+]") }
                .buttonStyle(PlainButtonStyle())
        )
        let node = HStack(alignment: .top, spacing: 1, children: cells, style: .plain).makeNode()
        return style.isPlain ? node : node.applyingStyle(style)
    }
}
