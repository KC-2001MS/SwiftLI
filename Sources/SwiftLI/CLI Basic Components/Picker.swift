//
//  Picker.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/07.
//

import Foundation

// MARK: - PickerStyle

/// The values passed to ``PickerStyle/makeBody(configuration:)`` when rendering.
public struct PickerStyleConfiguration: Sendable {
    /// The picker's text label.
    public let label: String
    /// The selectable options, in order.
    public let options: [String]
    /// The index of the selected option (clamped to `options`).
    public let selectedIndex: Int
    /// Whether the picker currently has keyboard focus.
    public let isFocused: Bool

    /// The selected option's text, or `""` when there are none.
    public var selection: String {
        options.indices.contains(selectedIndex) ? options[selectedIndex] : ""
    }
}

/// A type that defines the appearance of a ``Picker``.
///
/// Conform to `PickerStyle` and apply it with ``Picker/pickerStyle(_:)``.
/// Built-in styles: ``InlinePickerStyle`` (default), ``SegmentedPickerStyle``,
/// and ``ListPickerStyle``.
public protocol PickerStyle: Sendable {
    associatedtype Body: View
    @ViewBuilder func makeBody(configuration: PickerStyleConfiguration) -> Body
}

// MARK: - Built-in styles

/// A one-line picker showing the current option between arrows: `label ‹ Opt ›`.
public struct InlinePickerStyle: PickerStyle {
    public init() {}

    public func makeBody(configuration: PickerStyleConfiguration) -> some View {
        let arrowColor: Color = configuration.isFocused ? .cyan : .eight_bit(240)
        return HStack(spacing: 0) {
            if configuration.isFocused { Text(content: "> ").forgroundColor(.cyan) }
            if !configuration.label.isEmpty { Text(content: configuration.label + " ") }
            Text(content: "‹ ").forgroundColor(arrowColor)
            Text(content: configuration.selection).bold()
            Text(content: " ›").forgroundColor(arrowColor)
        }
    }
}

/// A horizontal segmented control: the selected option is bracketed and
/// coloured, the rest dimmed. `label [Opt1] Opt2 Opt3`.
public struct SegmentedPickerStyle: PickerStyle {
    public init() {}

    public func makeBody(configuration: PickerStyleConfiguration) -> some View {
        var cells: [any View] = []
        if configuration.isFocused { cells.append(Text(content: "> ").forgroundColor(.cyan)) }
        if !configuration.label.isEmpty { cells.append(Text(content: configuration.label + " ")) }
        for (index, option) in configuration.options.enumerated() {
            if index == configuration.selectedIndex {
                cells.append(Text(content: "[\(option)]").forgroundColor(.green).bold())
            } else {
                cells.append(Text(content: " \(option) ").forgroundColor(.eight_bit(244)))
            }
        }
        return HStack(spacing: 0) { Group(contents: cells) }
    }
}

/// A vertical list with a `❯` marker on the selected row. When focused the
/// selected row is bright cyan and bold and the header carries a `>`; when
/// unfocused the whole list dims so it clearly reads as inactive.
public struct ListPickerStyle: PickerStyle {
    public init() {}

    public func makeBody(configuration: PickerStyleConfiguration) -> some View {
        let focused = configuration.isFocused
        var rows: [any View] = []

        if !configuration.label.isEmpty {
            rows.append(HStack(spacing: 0) {
                Group(contents: [
                    Text(content: focused ? "> " : "  ").forgroundColor(.cyan),
                    Text(content: configuration.label).bold()
                ])
            })
        }

        for (index, option) in configuration.options.enumerated() {
            let selected = index == configuration.selectedIndex
            // Selected + focused stands out (cyan/bold); selected + unfocused is
            // still marked but dim; unselected rows are dimmest.
            let color: Color = selected
                ? (focused ? .cyan : .eight_bit(245))
                : (focused ? .primary : .eight_bit(240))
            let row = HStack(spacing: 0) {
                Group(contents: [
                    Text(content: selected ? "❯ " : "  ").forgroundColor(color),
                    Text(content: option).forgroundColor(color).bold(selected && focused)
                ])
            }
            rows.append(row)
        }
        return VStack(alignment: .leading, children: rows)
    }
}

// MARK: - AnyPickerStyle (type erasure)

/// A type-erased ``PickerStyle`` whose erased result is a ``Group``.
struct AnyPickerStyle: PickerStyle, @unchecked Sendable {
    private let _makeBody: (PickerStyleConfiguration) -> Group

    init<S: PickerStyle>(_ style: S) {
        _makeBody = { config in
            let result = style.makeBody(configuration: config)
            if let group = result as? Group { return group }
            return Group(contents: [result])
        }
    }

    func makeBody(configuration: PickerStyleConfiguration) -> Group {
        _makeBody(configuration)
    }
}

// MARK: - Picker

/// A focusable control that selects one of several options, bound to a
/// `Binding<Int>` (the selected option's index).
///
/// `Picker` mirrors SwiftUI's `Picker`, adapted to the terminal. While focused,
/// the arrows (or <kbd>Space</kbd>) move the selection, a digit `1`–`9` jumps to
/// an option, and <kbd>Tab</kbd> / <kbd>Shift-Tab</kbd> move focus. Its
/// appearance is chosen by a ``PickerStyle`` — ``InlinePickerStyle`` by default.
///
/// ```swift
/// @State var color = 0
///
/// var body: some View {
///     Picker("Color", selection: $color, options: ["Red", "Green", "Blue"])
///         .pickerStyle(SegmentedPickerStyle())
/// }
/// ```
public struct Picker: View {
    let header: String
    let id: String
    let label: String
    let options: [String]
    let selection: Binding<Int>
    let onSubmit: (() -> Void)?
    let style: AnyPickerStyle

    /// Creates a picker with a label, a selected-index binding, and options.
    /// - Parameters:
    ///   - label: The text shown beside the control; also the default identity.
    ///   - selection: The bound selected-option index.
    ///   - options: The selectable option titles.
    ///   - id: An explicit identity; defaults to the label.
    ///   - onSubmit: Called when <kbd>Return</kbd> is pressed while focused.
    public init(
        _ label: LocalizedStringKey = "",
        selection: Binding<Int>,
        options: [String],
        id: String? = nil,
        onSubmit: (() -> Void)? = nil
    ) {
        let resolved = String(localized: label.localizationValue)
        self.header = ""
        self.id = id ?? (resolved.isEmpty ? "Picker" : resolved)
        self.label = resolved
        self.options = options
        self.selection = selection
        self.onSubmit = onSubmit
        self.style = AnyPickerStyle(InlinePickerStyle())
    }

    init(header: String, id: String, label: String, options: [String], selection: Binding<Int>, onSubmit: (() -> Void)?, style: AnyPickerStyle) {
        self.header = header
        self.id = id
        self.label = label
        self.options = options
        self.selection = selection
        self.onSubmit = onSubmit
        self.style = style
    }

    public var body: some View { Group(contents: []) }

    @_spi(RenderingInternals)
    public func addHeader(_ newHeader: String) -> Self {
        Picker(header: newHeader + header, id: id, label: label, options: options, selection: selection, onSubmit: onSubmit, style: style)
    }

    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        FocusCoordinator.shared.registerPicker(id: id, selection: selection, count: options.count, onSubmit: onSubmit)
        KeyInputRouter.shared.ensureStarted()

        let index = options.isEmpty ? 0 : Swift.min(Swift.max(selection.wrappedValue, 0), options.count - 1)
        let configuration = PickerStyleConfiguration(
            label: label,
            options: options,
            selectedIndex: index,
            isFocused: FocusCoordinator.shared.isFocused(id)
        )
        let node = style.makeBody(configuration: configuration).makeNode()
        return header.isEmpty ? node : node.applyingHeader(header)
    }

    /// Sets the style used to render this picker.
    /// - Parameter newStyle: A value conforming to ``PickerStyle``.
    public func pickerStyle(_ newStyle: some PickerStyle) -> Self {
        Picker(header: header, id: id, label: label, options: options, selection: selection, onSubmit: onSubmit, style: AnyPickerStyle(newStyle))
    }
}
