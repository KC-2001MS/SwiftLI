//
//  Picker.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/07.
//

import Foundation

// MARK: - PickerStyle

/// The values passed to ``PickerStyle/makeBody(configuration:)`` when rendering.
public struct PickerStyleConfiguration {
    /// The picker's label view, or `nil` when the picker has no label.
    public let label: AnyView?
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
    /// Builds the terminal representation for a picker with the given configuration.
    /// - Parameter configuration: The style configuration containing label, options, selection, and focus state.
    /// - Returns: A view that renders the picker.
    @ViewBuilder func makeBody(configuration: PickerStyleConfiguration) -> Body
}

// MARK: - Built-in styles

/// A one-line picker showing the current option between arrows: `label ‹ Opt ›`.
public struct InlinePickerStyle: PickerStyle {
    /// Creates an inline picker style.
    public init() {}

    /// Builds the inline arrow-flanked representation of the picker.
    /// - Parameter configuration: The style configuration containing label, options, selection, and focus state.
    /// - Returns: A horizontal view with optional label and the selected option between arrow characters.
    public func makeBody(configuration: PickerStyleConfiguration) -> some View {
        let arrowColor: Color = configuration.isFocused ? .cyan : .eight_bit(240)
        return HStack(spacing: 0) {
            if configuration.isFocused { Text(content: "> ").forgroundColor(.cyan) }
            if let label = configuration.label {
                label
                Text(content: " ")
            }
            Text(content: "‹ ").forgroundColor(arrowColor)
            Text(content: configuration.selection).bold()
            Text(content: " ›").forgroundColor(arrowColor)
        }
    }
}

/// A horizontal segmented control: the selected option is bracketed and
/// coloured, the rest dimmed. `label [Opt1] Opt2 Opt3`.
public struct SegmentedPickerStyle: PickerStyle {
    /// Creates a segmented picker style.
    public init() {}

    /// Builds the segmented bracket representation of the picker.
    /// - Parameter configuration: The style configuration containing label, options, selection, and focus state.
    /// - Returns: A horizontal view where the selected option is highlighted in green brackets and unselected options are dimmed.
    public func makeBody(configuration: PickerStyleConfiguration) -> some View {
        var cells: [any View] = []
        if configuration.isFocused { cells.append(Text(content: "> ").forgroundColor(.cyan)) }
        if let label = configuration.label {
            cells.append(label)
            cells.append(Text(content: " "))
        }
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
    /// Creates a list picker style.
    public init() {}

    /// Builds the vertical list representation of the picker.
    /// - Parameter configuration: The style configuration containing label, options, selection, and focus state.
    /// - Returns: A vertical stack where each option appears as a labelled row with a `❯` marker on the selected item.
    public func makeBody(configuration: PickerStyleConfiguration) -> some View {
        let focused = configuration.isFocused
        var rows: [any View] = []

        if let label = configuration.label {
            rows.append(HStack(spacing: 0) {
                Group(contents: [
                    Text(content: focused ? "> " : "  ").forgroundColor(.cyan),
                    label.bold()
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

/// A type-erased ``PickerStyle`` whose erased result is an ``AnyView``.
struct AnyPickerStyle: PickerStyle, @unchecked Sendable {
    private let _makeBody: (PickerStyleConfiguration) -> any View

    init<S: PickerStyle>(_ style: S) {
        _makeBody = { style.makeBody(configuration: $0) }
    }

    func makeBody(configuration: PickerStyleConfiguration) -> AnyView {
        AnyView(erasing: _makeBody(configuration))
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
    let textStyle: TextStyle
    let id: String
    let label: AnyView?
    let options: [String]
    let selection: Binding<Int>
    /// The explicitly applied style, or `nil` to resolve from the environment.
    let style: AnyPickerStyle?

    /// Creates a picker with a text label, a selected-index binding, and options.
    ///
    /// A picker is a pure value editor — it has no submit hook. Pair it with a
    /// ``Button`` when a flow needs an explicit confirmation step.
    ///
    /// - Parameters:
    ///   - label: The text shown beside the control; also the default identity.
    ///   - selection: The bound selected-option index.
    ///   - options: The selectable option titles.
    ///   - id: An explicit identity; defaults to the label.
    public init(
        _ label: LocalizedStringKey = "",
        selection: Binding<Int>,
        options: [String],
        id: String? = nil
    ) {
        let resolved = String(localized: label.localizationValue)
        self.textStyle = .plain
        self.id = id ?? (resolved.isEmpty ? "Picker" : resolved)
        self.label = resolved.isEmpty ? nil : AnyView(Text(content: resolved))
        self.options = options
        self.selection = selection
        self.style = nil
    }

    /// Creates a picker with a custom label view.
    /// - Parameters:
    ///   - selection: The bound selected-option index.
    ///   - options: The selectable option titles.
    ///   - id: An explicit identity; defaults to `"Picker"` — give each picker
    ///     a distinct `id` when a screen shows more than one.
    ///   - label: A ``ViewBuilder`` producing the picker's label.
    public init<Label: View>(
        selection: Binding<Int>,
        options: [String],
        id: String = "Picker",
        @ViewBuilder label: () -> Label
    ) {
        self.textStyle = .plain
        self.id = id
        self.label = AnyView(label())
        self.options = options
        self.selection = selection
        self.style = nil
    }

    init(textStyle: TextStyle, id: String, label: AnyView?, options: [String], selection: Binding<Int>, style: AnyPickerStyle?) {
        self.textStyle = textStyle
        self.id = id
        self.label = label
        self.options = options
        self.selection = selection
        self.style = style
    }

    /// The rendered content of this picker, delegated to the resolved ``PickerStyle``.
    public var body: some View {
        EmptyView()
    }

    @_spi(RenderingInternals)
    public func applyingStyle(_ style: TextStyle) -> Self {
        Picker(textStyle: textStyle.inheriting(style), id: id, label: label, options: options, selection: selection, style: self.style)
    }

    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        FocusCoordinator.shared.registerPicker(id: id, selection: selection, count: options.count)
        KeyInputRouter.shared.ensureStarted()

        let index = options.isEmpty ? 0 : Swift.min(Swift.max(selection.wrappedValue, 0), options.count - 1)
        let configuration = PickerStyleConfiguration(
            label: label,
            options: options,
            selectedIndex: index,
            isFocused: FocusCoordinator.shared.isFocused(id)
        )
        // Nearest wins: instance style, then subtree environment, then default.
        let resolvedStyle = style ?? EnvironmentStack.current.pickerStyle ?? AnyPickerStyle(InlinePickerStyle())
        let node = resolvedStyle.makeBody(configuration: configuration).makeNode()
        return (textStyle.isPlain ? node : node.applyingStyle(textStyle)).asControl(id: id)
    }

    /// Sets the style used to render this picker.
    /// - Parameter newStyle: A value conforming to ``PickerStyle``.
    public func pickerStyle(_ newStyle: some PickerStyle) -> Self {
        Picker(textStyle: textStyle, id: id, label: label, options: options, selection: selection, style: AnyPickerStyle(newStyle))
    }
}
