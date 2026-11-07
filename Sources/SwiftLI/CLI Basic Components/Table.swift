//
//  Table.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/07.
//

import Foundation

/// One column of a ``Table``: a header title plus a way to read each row's text.
///
/// Mirroring SwiftUI's `TableColumn`, a column is created with a title and
/// either a key path or a closure that turns a row value into display text.
/// Give an explicit `width` to fix a column's column-count; otherwise it flexes
/// to share the table's width.
///
/// ```swift
/// TableColumn("Name") { $0.name }
/// TableColumn("Age", width: 4) { "\($0.age)" }
/// TableColumn("Email", value: \.email)
/// ```
public struct TableColumn<RowValue>: @unchecked Sendable {
    let title: String
    let value: (RowValue) -> String
    /// A fixed column width in columns, or `nil` to flex.
    let width: Int?

    /// Creates a column whose text is produced by a closure.
    public init(_ title: String, width: Int? = nil, value: @escaping (RowValue) -> String) {
        self.title = title
        self.width = width
        self.value = value
    }

    /// Creates a column whose text is read from a `String` key path.
    public init(_ title: String, width: Int? = nil, value keyPath: KeyPath<RowValue, String>) {
        self.init(title, width: width) { $0[keyPath: keyPath] }
    }
}

/// A result builder that collects the ``TableColumn``s of a ``Table``.
@resultBuilder
public enum TableColumnBuilder<RowValue> {
    /// Lifts a single ``TableColumn`` expression into the builder pipeline.
    public static func buildExpression(_ expression: TableColumn<RowValue>) -> TableColumn<RowValue> { expression }
    /// Combines multiple ``TableColumn`` expressions into an ordered array.
    public static func buildBlock(_ components: TableColumn<RowValue>...) -> [TableColumn<RowValue>] { components }
    /// Flattens an array of column arrays produced by control-flow statements such as `for`-`in`.
    public static func buildArray(_ components: [[TableColumn<RowValue>]]) -> [TableColumn<RowValue>] { components.flatMap { $0 } }
}

// MARK: - TableStyle protocol

/// The values passed to ``TableStyle/makeBody(configuration:)`` when rendering.
///
/// A ``Table`` calls its style once per row — the header row first, then one
/// body row per element — so a style decorates rows while the table keeps
/// ownership of column layout, the header rule, and scrolling.
public struct TableStyleConfiguration {
    /// One laid-out table row: the cells clipped to their column widths on a
    /// single line, not yet decorated.
    public let row: AnyView
    /// Whether this row is the header row (the column titles).
    public let isHeader: Bool
    /// Whether this row is the selected row.
    public let isSelected: Bool
    /// Whether the table currently has keyboard focus.
    public let isFocused: Bool
}

/// A type that defines the appearance of a ``Table``'s rows.
///
/// Conform to `TableStyle` and apply it with ``Table/tableStyle(_:)`` (or
/// ``View/tableStyle(_:)`` for a whole subtree). The default style is
/// ``DefaultTableStyle``.
public protocol TableStyle: Sendable {
    /// The type of view produced by this style.
    associatedtype Body: View

    /// Returns a view that represents one table row.
    ///
    /// Keep the result on a single line so the table's row-per-line scroll
    /// tracking stays accurate.
    ///
    /// - Parameter configuration: The laid-out row and its header/selection state.
    @ViewBuilder
    func makeBody(configuration: TableStyleConfiguration) -> Body
}

/// The default table style — a bold header row, and the selected row cyan and
/// bold while focused (dimmed when not). Equivalent to ``TableStyle/automatic``.
public struct DefaultTableStyle: TableStyle {
    /// Creates a default table style instance.
    public init() {}

    /// Returns a decorated view for one table row using the default styling rules.
    ///
    /// - Parameter configuration: The laid-out row and its header/selection state.
    public func makeBody(configuration: TableStyleConfiguration) -> AnyView {
        if configuration.isHeader {
            return AnyView(erasing: configuration.row.bold())
        }
        if configuration.isSelected && configuration.isFocused {
            return AnyView(erasing: configuration.row.foregroundStyle(.cyan).bold())
        }
        if configuration.isSelected {
            return AnyView(erasing: configuration.row.foregroundStyle(.eightBit(245)))
        }
        return configuration.row
    }
}

public extension TableStyle where Self == DefaultTableStyle {
    /// The default table style: a bold header and a highlighted selected row.
    static var automatic: Self { .init() }
}

// MARK: - AnyTableStyle (type erasure)

/// A type-erased ``TableStyle`` whose erased result is an ``AnyView`` — a
/// plain composition of views, matching how ``AnyToggleStyle`` works.
struct AnyTableStyle: TableStyle, @unchecked Sendable {
    private let _makeBody: (TableStyleConfiguration) -> any View

    init<S: TableStyle>(_ style: S) {
        _makeBody = { style.makeBody(configuration: $0) }
    }

    func makeBody(configuration: TableStyleConfiguration) -> AnyView {
        AnyView(erasing: _makeBody(configuration))
    }
}

// MARK: - Table

/// A data-driven grid of rows and columns, laid out to fill the terminal width.
///
/// `Table` mirrors SwiftUI's `Table`: you give it a collection and describe its
/// columns with ``TableColumn``. It draws a bold header, a rule beneath it, and
/// one row per element. The table always takes the **maximum available width**
/// (the terminal's columns): flexible columns share the leftover space, and any
/// cell that would overflow its column is truncated with an ellipsis.
///
/// ```swift
/// struct Person { let name: String; let role: String; let email: String }
///
/// Table(people) {
///     TableColumn("Name") { $0.name }
///     TableColumn("Role", width: 12) { $0.role }
///     TableColumn("Email") { $0.email }
/// }
/// ```
///
/// ## Scrolling and selection
///
/// Constrain the height with `.frame(height:)` and, when there are more rows
/// than fit, the **header and rule stay pinned** while the body scrolls (a
/// scrollbar is drawn to the right). Add a `selection` binding to make the
/// table focusable: the arrow keys move a highlighted row and the body scrolls
/// to follow, Home/End jump to the ends, and Tab moves focus on. With a
/// constrained height but no `selection` the table scrolls freely with the
/// arrows, like a ``ScrollView``.
///
/// ```swift
/// Table(people, selection: $selected) {
///     TableColumn("Name") { $0.name }
///     TableColumn("Email") { $0.email }
/// }
/// .frame(height: 10)
/// ```
public struct Table<Data: RandomAccessCollection>: View, @unchecked Sendable {
    /// Columns are separated by this many blank columns.
    private static var columnGap: Int { 2 }

    private let textStyle: TextStyle
    private let id: String
    private let data: Data
    private let columns: [TableColumn<Data.Element>]
    private let selection: Binding<Int?>?
    /// The explicitly applied style, or `nil` to resolve from the environment.
    private let style: AnyTableStyle?

    /// Creates a table over `data`, described by the columns in the builder.
    ///
    /// The selection is a pure value — the table has no submit hook. Pair it
    /// with a ``Button`` when a flow needs to act on the chosen row.
    ///
    /// - Parameters:
    ///   - data: The rows' backing collection.
    ///   - selection: A bound selected-row index; pass `nil` for no selection.
    ///   - id: A stable identity for focus/scroll state.
    ///   - columns: The column definitions.
    public init(
        _ data: Data,
        selection: Binding<Int?>? = nil,
        id: String = "Table",
        @TableColumnBuilder<Data.Element> columns: () -> [TableColumn<Data.Element>]
    ) {
        self.textStyle = .plain
        self.id = id
        self.data = data
        self.columns = columns()
        self.selection = selection
        self.style = nil
    }

    init(textStyle: TextStyle, id: String, data: Data, columns: [TableColumn<Data.Element>], selection: Binding<Int?>?, style: AnyTableStyle? = nil) {
        self.textStyle = textStyle
        self.id = id
        self.data = data
        self.columns = columns
        self.selection = selection
        self.style = style
    }

    /// The pinned header and rule above the body rows (scrolled when a height
    /// bounds them), each decorated by the resolved ``TableStyle``, carrying
    /// the table's own text style and — when selectable or scrolling — marked
    /// as the table's pointer footprint. Evaluating it also registers the
    /// table for keyboard handling.
    public var body: some View {
        if !columns.isEmpty {
            let layout = self.layout
            let isFocused = self.isFocused
            VStack(alignment: .leading, spacing: 0) {
                // Pinned header row (decorated by the style) and the rule
                // beneath it.
                header(layout: layout, isFocused: isFocused)
                Text(repeating: "─", count: Swift.max(layout.totalWidth, 0))
                    .foregroundStyle(.eightBit(240))
                // Scroll only the body by composing a controlled
                // ``ScrollView`` (which owns the .scroll IR and the scrollbar).
                if scrolls {
                    ScrollView(
                        height: resolvedHeight,
                        offset: selection != nil ? FocusCoordinator.shared.listOffset(for: id) : FocusCoordinator.shared.scrollOffset(for: id),
                        focused: isFocused,
                        content: bodyRows(layout: layout, isFocused: isFocused)
                    )
                } else {
                    VStack(alignment: .leading, spacing: 0, children: bodyRows(layout: layout, isFocused: isFocused))
                }
            }
        }
    }

    /// Whether the table is interactive: selectable, or scrolling its body.
    private var isInteractive: Bool {
        selection != nil || scrolls
    }

    private var isFocused: Bool {
        isInteractive && FocusCoordinator.shared.isFocused(id)
    }

    /// The rows and the column widths resolved for them.
    private struct Layout {
        let rows: [Data.Element]
        let widths: [Int]
        let totalWidth: Int
    }

    private var layout: Layout {
        let rows = Array(data)
        let widths = resolvedWidths(rows: rows)
        return Layout(rows: rows, widths: widths, totalWidth: widths.reduce(0, +) + Self.columnGap * (widths.count - 1))
    }

    /// `.frame(height:)` pins `maxHeight` to the table's total height; the
    /// pinned header and rule take two of those rows, the body the rest.
    private var resolvedHeight: Int {
        Swift.max(1, EnvironmentStack.current.maxHeight - 2)
    }

    private var scrolls: Bool {
        data.count > resolvedHeight
    }

    /// Nearest wins: instance style, then subtree environment, then default.
    private var resolvedStyle: AnyTableStyle {
        style ?? EnvironmentStack.current.tableStyle ?? AnyTableStyle(DefaultTableStyle())
    }

    private func header(layout: Layout, isFocused: Bool) -> AnyView {
        resolvedStyle.makeBody(configuration: TableStyleConfiguration(
            row: AnyView(erasing: row(cells: columns.map { $0.title }, widths: layout.widths, gap: Self.columnGap)),
            isHeader: true, isSelected: false, isFocused: isFocused
        ))
    }

    /// One row per element, each decorated by the style.
    private func bodyRows(layout: Layout, isFocused: Bool) -> [any View] {
        let selectedIndex = selection?.wrappedValue
        return layout.rows.enumerated().map { index, element in
            resolvedStyle.makeBody(configuration: TableStyleConfiguration(
                row: AnyView(erasing: row(cells: columns.map { $0.value(element) }, widths: layout.widths, gap: Self.columnGap)),
                isHeader: false, isSelected: index == selectedIndex, isFocused: isFocused
            ))
        }
    }

    @_spi(RenderingInternals)
    public func applyingStyle(_ style: TextStyle) -> Self {
        Table(textStyle: textStyle.inheriting(style), id: id, data: data, columns: columns, selection: selection, style: self.style)
    }

    /// Registers the table for keyboard handling — as a list when selectable,
    /// as a scroll view when it merely scrolls — then lowers ``body`` with the
    /// table's own text style cascaded onto it, as the table's pointer
    /// footprint when interactive.
    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        guard !columns.isEmpty else { return .empty }
        if let selection {
            FocusCoordinator.shared.registerList(id: id, selection: selection, count: data.count, viewportRows: scrolls ? resolvedHeight : nil)
            KeyInputRouter.shared.ensureStarted()
        } else if scrolls {
            FocusCoordinator.shared.registerScroll(id: id, viewportHeight: resolvedHeight, contentHeight: data.count)
            KeyInputRouter.shared.ensureStarted()
        }
        let node = body.makeNode()
        let styled = textStyle.isPlain ? node : node.applyingStyle(textStyle)
        return isInteractive ? styled.asControl(id: id) : styled
    }

    /// Builds one undecorated table row: each cell clipped to its column width
    /// on a single line. Emphasis (header bold, selection highlight) is applied
    /// by the active ``TableStyle``.
    private func row(cells: [String], widths: [Int], gap: Int) -> any View {
        var views: [any View] = []
        for (i, text) in cells.enumerated() where i < widths.count {
            let cell = Text(content: text)
                .frame(width: widths[i], alignment: .topLeading)
                .lineLimit(1)
            views.append(cell)
        }
        return HStack(alignment: .top, spacing: gap) { Group(contents: views) }
    }

    /// Sets the style used to decorate this table's rows.
    ///
    /// - Parameter newStyle: A value conforming to ``TableStyle``.
    public func tableStyle(_ newStyle: some TableStyle) -> Self {
        Table(textStyle: textStyle, id: id, data: data, columns: columns, selection: selection, style: AnyTableStyle(newStyle))
    }

    /// Resolves each column's width so the row fills the terminal: flexible
    /// columns share any leftover space; if the natural widths overflow, they
    /// shrink proportionally (never below a small minimum).
    private func resolvedWidths(rows: [Data.Element]) -> [Int] {
        let available = TerminalSize.current.columns
        let gap = Self.columnGap
        let content = Swift.max(0, available - gap * (columns.count - 1))

        // Natural width = widest of the header and every cell in the column.
        var natural = columns.map { TextMetrics.visibleWidth($0.title) }
        for element in rows {
            for (i, column) in columns.enumerated() {
                natural[i] = Swift.max(natural[i], TextMetrics.visibleWidth(column.value(element)))
            }
        }

        // Fixed columns keep their width; flexible ones start at their natural width.
        var widths = columns.enumerated().map { i, column in column.width ?? natural[i] }
        let flexible = columns.indices.filter { columns[$0].width == nil }

        let total = widths.reduce(0, +)
        if total == content || flexible.isEmpty { return widths.map { Swift.max($0, 1) } }

        if total < content {
            // Distribute the leftover columns evenly across flexible columns.
            var leftover = content - total
            var k = 0
            while leftover > 0 {
                widths[flexible[k % flexible.count]] += 1
                leftover -= 1
                k += 1
            }
        } else {
            // Overflow: shrink flexible columns proportionally to fit.
            let flexTotal = flexible.reduce(0) { $0 + widths[$1] }
            let fixedTotal = total - flexTotal
            let flexBudget = Swift.max(flexible.count, content - fixedTotal)
            var assigned = 0
            for (n, idx) in flexible.enumerated() {
                if n == flexible.count - 1 {
                    widths[idx] = Swift.max(1, flexBudget - assigned)
                } else {
                    let share = Swift.max(1, widths[idx] * flexBudget / Swift.max(flexTotal, 1))
                    widths[idx] = share
                    assigned += share
                }
            }
        }
        return widths.map { Swift.max($0, 1) }
    }
}
