//
//  Grid.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/09.
//


/// A grid that lays its children out in a fixed number of **columns**, filling
/// left-to-right and wrapping onto a new row every `columns` items.
///
/// Column widths are aligned across rows: each column is as wide as its widest
/// cell, so items line up in neat columns. Mirrors a simplified SwiftUI
/// `LazyVGrid` with a fixed column count.
///
/// ```swift
/// VGrid(columns: 3) {
///     ForEach(0..<9) { Text("Item \($0)") }
/// }
/// ```
public struct VGrid: View {
    let columns: Int
    let spacing: Int
    let children: [any View]

    /// Creates a grid with a fixed number of columns.
    ///
    /// - Parameters:
    ///   - columns: The number of columns (clamped to at least 1).
    ///   - spacing: Blank columns/rows between cells. Defaults to `1`.
    ///   - content: A ``ViewBuilder`` producing the cells.
    public init<Content: View>(columns: Int, spacing: Int = 1, @ViewBuilder content: () -> Content) {
        self.columns = Swift.max(1, columns)
        self.spacing = spacing
        self.children = content()._flattenedChildren()
    }

    /// The content of the grid, rendered as a vertical stack of rows.
    public var body: some View {
        VStack(alignment: .leading, spacing: spacing, children: rows)
    }

    /// The children chunked into rows, each cell padded to its column width.
    private var rows: [any View] {
        let cols = columns

        // Column widths: the widest cell in each column, so columns align.
        var colWidth = Array(repeating: 0, count: cols)
        for (i, child) in children.enumerated() {
            let w = NodeLayout.measure(child.makeNode()).width
            colWidth[i % cols] = Swift.max(colWidth[i % cols], w)
        }

        var rows: [any View] = []
        var i = 0
        while i < children.count {
            let end = Swift.min(i + cols, children.count)
            var cells: [any View] = []
            for c in 0..<(end - i) {
                cells.append(children[i + c].frame(width: colWidth[c], alignment: .topLeading))
            }
            rows.append(HStack(alignment: .top, spacing: spacing, children: cells, style: .plain))
            i = end
        }
        return rows
    }
}

/// A grid that lays its children out in a fixed number of **rows**, filling
/// top-to-bottom and wrapping into a new column every `rows` items.
///
/// Row heights are aligned across columns: each row is as tall as its tallest
/// cell. Mirrors a simplified SwiftUI `LazyHGrid` with a fixed row count.
///
/// ```swift
/// HGrid(rows: 2) {
///     ForEach(0..<8) { Text("Item \($0)") }
/// }
/// ```
public struct HGrid: View {
    let rows: Int
    let spacing: Int
    let children: [any View]

    /// Creates a grid with a fixed number of rows.
    ///
    /// - Parameters:
    ///   - rows: The number of rows (clamped to at least 1).
    ///   - spacing: Blank columns/rows between cells. Defaults to `1`.
    ///   - content: A ``ViewBuilder`` producing the cells.
    public init<Content: View>(rows: Int, spacing: Int = 1, @ViewBuilder content: () -> Content) {
        self.rows = Swift.max(1, rows)
        self.spacing = spacing
        self.children = content()._flattenedChildren()
    }

    /// The content of the grid, rendered as a horizontal stack of columns.
    public var body: some View {
        HStack(alignment: .top, spacing: spacing, children: columns, style: .plain)
    }

    /// The children chunked into columns, each cell padded to its row height.
    private var columns: [any View] {
        let rowCount = rows

        // Row heights: the tallest cell in each row, so rows align across columns.
        var rowHeight = Array(repeating: 0, count: rowCount)
        for (i, child) in children.enumerated() {
            let h = NodeLayout.measure(child.makeNode()).height
            rowHeight[i % rowCount] = Swift.max(rowHeight[i % rowCount], h)
        }

        var columns: [any View] = []
        var i = 0
        while i < children.count {
            let end = Swift.min(i + rowCount, children.count)
            var cells: [any View] = []
            for r in 0..<(end - i) {
                cells.append(children[i + r].frame(height: rowHeight[r], alignment: .topLeading))
            }
            columns.append(VStack(alignment: .leading, spacing: spacing, children: cells))
            i = end
        }
        return columns
    }
}
