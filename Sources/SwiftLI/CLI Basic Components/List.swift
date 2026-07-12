//
//  List.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/07.
//

import Foundation

// MARK: - ListStyle protocol

/// The values passed to ``ListStyle/makeBody(configuration:)`` when rendering.
public struct ListStyleConfiguration {
    /// The row contents, one per element, in order and not yet decorated.
    public let rows: [AnyView]
    /// The index of the selected row, or `nil` when nothing is selected.
    public let selectedIndex: Int?
    /// Whether the list currently has keyboard focus.
    public let isFocused: Bool
    /// Whether the list is selectable (it was given a `selection` binding).
    public let isSelectable: Bool
}

/// A type that defines the appearance of a ``List``.
///
/// Conform to `ListStyle` and apply it with ``List/listStyle(_:)`` (or
/// ``View/listStyle(_:)`` for a whole subtree). The style receives every row
/// plus the selection state and returns the stacked, decorated rows; the list
/// itself still owns scrolling. The default style is ``PlainListStyle``.
public protocol ListStyle: Sendable {
    /// The type of view produced by this style.
    associatedtype Body: View

    /// Returns a view that represents the list's rows.
    ///
    /// Emit one line per row so the list's scroll-offset tracking (which
    /// assumes one line per row) stays accurate.
    ///
    /// - Parameter configuration: The rows and the current selection state.
    @ViewBuilder
    func makeBody(configuration: ListStyleConfiguration) -> Body
}

/// The plain list style — a `❯` marker on the selected row, highlighted cyan
/// and bold while focused and dimmed when not. Equivalent to
/// ``ListStyle/plain`` and the default appearance.
public struct PlainListStyle: ListStyle {
    /// Creates a plain list style.
    public init() {}

    /// Returns a view that stacks the rows with a selection marker on the active row.
    ///
    /// - Parameter configuration: The rows and the current selection state.
    public func makeBody(configuration: ListStyleConfiguration) -> some View {
        var rowViews: [any View] = []
        for (index, row) in configuration.rows.enumerated() {
            let selected = index == configuration.selectedIndex
            rowViews.append(styledRow(row, selected: selected, focused: configuration.isFocused, selectable: configuration.isSelectable))
        }
        return VStack(alignment: .leading, spacing: 0, children: rowViews)
    }

    /// A single row: a selection marker plus the row content, highlighted when
    /// selected (bright when focused, dim when not).
    private func styledRow(_ row: AnyView, selected: Bool, focused: Bool, selectable: Bool) -> any View {
        let markerColor: Color = selected ? (focused ? .cyan : .eight_bit(245)) : .eight_bit(240)
        let marker = Text(content: selectable ? (selected ? "❯ " : "  ") : "").forgroundColor(markerColor)

        let base = HStack(alignment: .top, spacing: 0, children: [marker, row], style: .plain)
        if selected && focused { return base.forgroundColor(.cyan).bold() }
        if selected            { return base.forgroundColor(.eight_bit(245)) }
        return base
    }
}

/// The default list style — resolves to ``PlainListStyle``. Equivalent to
/// ``ListStyle/automatic``.
public struct DefaultListStyle: ListStyle {
    /// Creates a default list style.
    public init() {}

    /// Returns a view by delegating to ``PlainListStyle``.
    ///
    /// - Parameter configuration: The rows and the current selection state.
    public func makeBody(configuration: ListStyleConfiguration) -> some View {
        PlainListStyle().makeBody(configuration: configuration)
    }
}

public extension ListStyle where Self == DefaultListStyle {
    /// The default list style (the same appearance as ``PlainListStyle``).
    static var automatic: Self { .init() }
}

public extension ListStyle where Self == PlainListStyle {
    /// The plain list style: a marker on the selected row, no extra chrome.
    static var plain: Self { .init() }
}

// MARK: - AnyListStyle (type erasure)

/// A type-erased ``ListStyle`` whose erased result is an ``AnyView`` — a
/// plain composition of views, matching how ``AnyToggleStyle`` works.
struct AnyListStyle: ListStyle, @unchecked Sendable {
    private let _makeBody: (ListStyleConfiguration) -> any View

    init<S: ListStyle>(_ style: S) {
        _makeBody = { style.makeBody(configuration: $0) }
    }

    func makeBody(configuration: ListStyleConfiguration) -> AnyView {
        AnyView(erasing: _makeBody(configuration))
    }
}

// MARK: - List

/// A data-driven, optionally selectable and scrolling column of rows.
///
/// `List` mirrors SwiftUI's `List`: give it a collection and a row builder and
/// it renders one row per element. Pass a `selection` binding to make it
/// focusable — the arrow keys then move a highlighted selection
/// (<kbd>Home</kbd>/<kbd>End</kbd> jump to the ends, <kbd>Return</kbd> submits),
/// and <kbd>Tab</kbd> moves focus on to the next control. Give a `height` and,
/// when there are more rows than fit, the list scrolls to keep the selected row
/// in view, drawing a scrollbar to the right.
///
/// ```swift
/// @State var selected: Int? = 0
///
/// var body: some View {
///     List(fruits, selection: $selected, height: 8) { fruit in
///         Text(fruit)
///     }
/// }
/// ```
///
/// Without a `selection` the list is a plain, non-focusable column of rows.
///
/// > Note: When the list scrolls, offset tracking assumes one line per row.
public struct List<Data: RandomAccessCollection, RowContent: View>: View, @unchecked Sendable {
    private let textStyle: TextStyle
    private let id: String
    private let data: Data
    private let selection: Binding<Int?>?
    private let height: Int?
    private let rowContent: (Data.Element) -> RowContent
    /// The explicitly applied style, or `nil` to resolve from the environment.
    private let style: AnyListStyle?

    /// Creates a list over `data`.
    ///
    /// The selection is a pure value — the list has no submit hook. Pair it
    /// with a ``Button`` when a flow needs to act on the chosen row.
    ///
    /// - Parameters:
    ///   - data: The rows' backing collection.
    ///   - selection: A bound selected-row index; pass `nil` for a static list.
    ///   - height: The visible-row count; when exceeded the list scrolls.
    ///   - id: A stable identity for focus/scroll state.
    ///   - rowContent: Builds the view for one element.
    public init(
        _ data: Data,
        selection: Binding<Int?>? = nil,
        height: Int? = nil,
        id: String = "List",
        @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent
    ) {
        self.textStyle = .plain
        self.id = id
        self.data = data
        self.selection = selection
        self.height = height
        self.rowContent = rowContent
        self.style = nil
    }

    init(textStyle: TextStyle, id: String, data: Data, selection: Binding<Int?>?, height: Int?, rowContent: @escaping (Data.Element) -> RowContent, style: AnyListStyle? = nil) {
        self.textStyle = textStyle
        self.id = id
        self.data = data
        self.selection = selection
        self.height = height
        self.rowContent = rowContent
        self.style = style
    }

    /// The content of the list; always ``EmptyView`` because rendering is handled by ``makeNode()``.
    public var body: some View {
        EmptyView()
    }

    @_spi(RenderingInternals)
    public func applyingStyle(_ style: TextStyle) -> Self {
        List(textStyle: textStyle.inheriting(style), id: id, data: data, selection: selection, height: height, rowContent: rowContent, style: self.style)
    }

    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        let rows = Array(data)
        let resolvedHeight = height ?? EnvironmentStack.current.maxHeight

        var focused = false
        var selectedIndex: Int? = nil
        if let selection {
            let scrolls = rows.count > resolvedHeight
            FocusCoordinator.shared.registerList(id: id, selection: selection, count: rows.count, viewportRows: scrolls ? resolvedHeight : nil)
            KeyInputRouter.shared.ensureStarted()
            focused = FocusCoordinator.shared.isFocused(id)
            selectedIndex = selection.wrappedValue
        }

        // Hand every row plus the selection state to the active style, which
        // returns the stacked, decorated rows.
        // Nearest wins: instance style, then subtree environment, then default.
        let resolvedStyle = style ?? EnvironmentStack.current.listStyle ?? AnyListStyle(PlainListStyle())
        let styledBody = resolvedStyle.makeBody(configuration: ListStyleConfiguration(
            rows: rows.map { AnyView(erasing: rowContent($0)) },
            selectedIndex: selectedIndex,
            isFocused: focused,
            isSelectable: selection != nil
        ))
        // Scroll to keep the selection visible when a height is set and exceeded,
        // by composing a controlled ``ScrollView`` (which owns the .scroll IR and
        // the scrollbar); otherwise just render the styled rows.
        let node: RenderNode
        if rows.count > resolvedHeight, selection != nil {
            let offset = FocusCoordinator.shared.listOffset(for: id)
            node = ScrollView(height: resolvedHeight, offset: offset, focused: focused, showsIndicators: true, content: [styledBody]).makeNode()
        } else {
            node = styledBody.makeNode()
        }
        let styled = textStyle.isPlain ? node : node.applyingStyle(textStyle)
        // Only a selectable list is a control; a static list stays inert.
        return selection != nil ? styled.asControl(id: id) : styled
    }

    /// Sets the style used to compose this list's rows.
    ///
    /// - Parameter newStyle: A value conforming to ``ListStyle``.
    public func listStyle(_ newStyle: some ListStyle) -> Self {
        List(textStyle: textStyle, id: id, data: data, selection: selection, height: height, rowContent: rowContent, style: AnyListStyle(newStyle))
    }
}

// MARK: - Static content

public extension List where Data == [AnyView], RowContent == AnyView {
    /// Creates a list from static view content, one row per top-level view.
    ///
    /// Mirrors SwiftUI's static `List { ... }`. Rows that are interactive on
    /// their own (``NavigationLink``, ``Button``) keep their behaviour — the
    /// typical use is a navigation sidebar:
    ///
    /// ```swift
    /// NavigationSplitView {
    ///     List {
    ///         NavigationLink("General") { GeneralView() }
    ///         NavigationLink("Network") { NetworkView() }
    ///     }
    /// } detail: {
    ///     Text("Select a section")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - selection: A bound selected-row index; pass `nil` (the default)
    ///     when the rows handle interaction themselves.
    ///   - height: The visible-row count; when exceeded the list scrolls.
    ///   - id: A stable identity for focus/scroll state.
    ///   - content: A ``ViewBuilder`` whose top-level views become the rows.
    init(
        selection: Binding<Int?>? = nil,
        height: Int? = nil,
        id: String = "List",
        @ViewBuilder content: () -> some View
    ) {
        let rows = content()._flattenedChildren().map { AnyView(erasing: $0) }
        self.init(rows, selection: selection, height: height, id: id) { $0 }
    }
}
