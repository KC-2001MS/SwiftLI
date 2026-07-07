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
    public static func buildExpression(_ expression: TableColumn<RowValue>) -> TableColumn<RowValue> { expression }
    public static func buildBlock(_ components: TableColumn<RowValue>...) -> [TableColumn<RowValue>] { components }
    public static func buildArray(_ components: [[TableColumn<RowValue>]]) -> [TableColumn<RowValue>] { components.flatMap { $0 } }
}

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
/// Pass a `height` and, when there are more rows than fit, the **header and
/// rule stay pinned** while the body scrolls (a scrollbar is drawn to the
/// right). Add a `selection` binding to make the table focusable: the arrow
/// keys move a highlighted row and the body scrolls to follow, Home/End jump to
/// the ends, and Tab moves focus on. With a `height` but no `selection` the
/// table scrolls freely with the arrows, like a ``ScrollView``.
///
/// ```swift
/// Table(people, selection: $selected, height: 10) {
///     TableColumn("Name") { $0.name }
///     TableColumn("Email") { $0.email }
/// }
/// ```
public struct Table<Data: RandomAccessCollection>: View, @unchecked Sendable {
    /// Columns are separated by this many blank columns.
    private static var columnGap: Int { 2 }

    private let header: String
    private let id: String
    private let data: Data
    private let columns: [TableColumn<Data.Element>]
    private let selection: Binding<Int?>?
    private let height: Int?
    private let onSubmit: (() -> Void)?

    /// Creates a table over `data`, described by the columns in the builder.
    /// - Parameters:
    ///   - data: The rows' backing collection.
    ///   - selection: A bound selected-row index; pass `nil` for no selection.
    ///   - height: The visible body-row count; when exceeded the body scrolls.
    ///   - id: A stable identity for focus/scroll state.
    ///   - onSubmit: Called on <kbd>Return</kbd> while focused.
    ///   - columns: The column definitions.
    public init(
        _ data: Data,
        selection: Binding<Int?>? = nil,
        height: Int? = nil,
        id: String = "Table",
        onSubmit: (() -> Void)? = nil,
        @TableColumnBuilder<Data.Element> columns: () -> [TableColumn<Data.Element>]
    ) {
        self.header = ""
        self.id = id
        self.data = data
        self.columns = columns()
        self.selection = selection
        self.height = height
        self.onSubmit = onSubmit
    }

    init(header: String, id: String, data: Data, columns: [TableColumn<Data.Element>], selection: Binding<Int?>?, height: Int?, onSubmit: (() -> Void)?) {
        self.header = header
        self.id = id
        self.data = data
        self.columns = columns
        self.selection = selection
        self.height = height
        self.onSubmit = onSubmit
    }

    public var body: some View { Group(contents: []) }

    @_spi(RenderingInternals)
    public func addHeader(_ newHeader: String) -> Self {
        Table(header: newHeader + header, id: id, data: data, columns: columns, selection: selection, height: height, onSubmit: onSubmit)
    }

    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        guard !columns.isEmpty else { return .empty }

        let rows = Array(data)
        let widths = resolvedWidths(rows: rows)
        let gap = Self.columnGap
        let totalWidth = widths.reduce(0, +) + gap * (widths.count - 1)

        // Register for input; decide focus + selection + scroll behaviour.
        let scrolls = height != nil && rows.count > (height ?? 0)
        var focused = false
        var selectedIndex: Int? = nil
        if let selection {
            FocusCoordinator.shared.registerList(id: id, selection: selection, count: rows.count, viewportRows: scrolls ? height : nil, onSubmit: onSubmit)
            KeyInputRouter.shared.ensureStarted()
            focused = FocusCoordinator.shared.isFocused(id)
            selectedIndex = selection.wrappedValue
        } else if scrolls {
            FocusCoordinator.shared.registerScroll(id: id, viewportHeight: height ?? 0, contentHeight: rows.count, onSubmit: onSubmit)
            KeyInputRouter.shared.ensureStarted()
            focused = FocusCoordinator.shared.isFocused(id)
        }

        // Pinned header row (bold) and the rule beneath it.
        let headerNode = row(cells: columns.map { $0.title }, widths: widths, gap: gap, bold: true, highlight: nil)
            .makeNode()
        let ruleNode = Text(repeating: "─", count: Swift.max(totalWidth, 0))
            .forgroundColor(.eight_bit(240)).makeNode()

        // Body: one row per element, with the selected row highlighted.
        var bodyRows: [any View] = []
        for (index, element) in rows.enumerated() {
            let mark: RowHighlight? = (index == selectedIndex) ? (focused ? .focused : .selected) : nil
            bodyRows.append(row(cells: columns.map { $0.value(element) }, widths: widths, gap: gap, bold: false, highlight: mark))
        }
        // Pin the header/rule; scroll only the body by composing a controlled
        // ``ScrollView`` (which owns the .scroll IR and the scrollbar).
        let bodyNode: RenderNode
        if scrolls, let height {
            let offset = selection != nil ? FocusCoordinator.shared.listOffset(for: id) : FocusCoordinator.shared.scrollOffset(for: id)
            bodyNode = ScrollView(height: height, offset: offset, focused: focused, showsIndicators: true, content: bodyRows).makeNode()
        } else {
            bodyNode = VStack(alignment: .leading, spacing: 0, children: bodyRows).makeNode()
        }

        let node = RenderNode.vstack(alignment: .leading, spacing: 0, children: [headerNode, ruleNode, bodyNode])
        return header.isEmpty ? node : node.applyingHeader(header)
    }

    /// How a body row is emphasised.
    private enum RowHighlight { case selected, focused }

    /// Builds one table row: each cell clipped to its column width on a single
    /// line, optionally highlighted when it is the selected row.
    private func row(cells: [String], widths: [Int], gap: Int, bold: Bool, highlight: RowHighlight?) -> any View {
        var views: [any View] = []
        for (i, text) in cells.enumerated() where i < widths.count {
            let cell = Text(content: text)
                .bold(bold)
                .frame(width: widths[i], alignment: .topLeading)
                .lineLimit(1)
            views.append(cell)
        }
        let base = HStack(alignment: .top, spacing: gap) { Group(contents: views) }
        switch highlight {
        case .focused:  return base.forgroundColor(.cyan).bold()
        case .selected: return base.forgroundColor(.eight_bit(245))
        case .none:     return base
        }
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
