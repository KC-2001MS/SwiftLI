//
//  List.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/07.
//

import Foundation

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
    private let header: String
    private let id: String
    private let data: Data
    private let selection: Binding<Int?>?
    private let height: Int?
    private let rowContent: (Data.Element) -> RowContent
    private let onSubmit: (() -> Void)?

    /// Creates a list over `data`.
    /// - Parameters:
    ///   - data: The rows' backing collection.
    ///   - selection: A bound selected-row index; pass `nil` for a static list.
    ///   - height: The visible-row count; when exceeded the list scrolls.
    ///   - id: A stable identity for focus/scroll state.
    ///   - onSubmit: Called on <kbd>Return</kbd> while focused.
    ///   - rowContent: Builds the view for one element.
    public init(
        _ data: Data,
        selection: Binding<Int?>? = nil,
        height: Int? = nil,
        id: String = "List",
        onSubmit: (() -> Void)? = nil,
        @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent
    ) {
        self.header = ""
        self.id = id
        self.data = data
        self.selection = selection
        self.height = height
        self.onSubmit = onSubmit
        self.rowContent = rowContent
    }

    init(header: String, id: String, data: Data, selection: Binding<Int?>?, height: Int?, onSubmit: (() -> Void)?, rowContent: @escaping (Data.Element) -> RowContent) {
        self.header = header
        self.id = id
        self.data = data
        self.selection = selection
        self.height = height
        self.onSubmit = onSubmit
        self.rowContent = rowContent
    }

    public var body: some View {
        EmptyView()
    }

    @_spi(RenderingInternals)
    public func addHeader(_ newHeader: String) -> Self {
        List(header: newHeader + header, id: id, data: data, selection: selection, height: height, onSubmit: onSubmit, rowContent: rowContent)
    }

    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        let rows = Array(data)

        var focused = false
        var selectedIndex: Int? = nil
        if let selection {
            let scrolls = height != nil && rows.count > (height ?? 0)
            FocusCoordinator.shared.registerList(id: id, selection: selection, count: rows.count, viewportRows: scrolls ? height : nil, onSubmit: onSubmit)
            KeyInputRouter.shared.ensureStarted()
            focused = FocusCoordinator.shared.isFocused(id)
            selectedIndex = selection.wrappedValue
        }

        // Build one styled row per element.
        var rowViews: [any View] = []
        for (index, element) in rows.enumerated() {
            rowViews.append(styledRow(element, index: index, selected: index == selectedIndex, focused: focused))
        }
        // Scroll to keep the selection visible when a height is set and exceeded,
        // by composing a controlled ``ScrollView`` (which owns the .scroll IR and
        // the scrollbar); otherwise just stack the rows.
        let node: RenderNode
        if let height, rows.count > height, selection != nil {
            let offset = FocusCoordinator.shared.listOffset(for: id)
            node = ScrollView(height: height, offset: offset, focused: focused, showsIndicators: true, content: rowViews).makeNode()
        } else {
            node = VStack(alignment: .leading, spacing: 0, children: rowViews).makeNode()
        }
        return header.isEmpty ? node : node.applyingHeader(header)
    }

    /// A single row: a selection marker plus the row content, highlighted when
    /// selected (bright when focused, dim when not).
    private func styledRow(_ element: Data.Element, index: Int, selected: Bool, focused: Bool) -> any View {
        let selectable = selection != nil
        let markerColor: Color = selected ? (focused ? .cyan : .eight_bit(245)) : .eight_bit(240)
        let marker = Text(content: selectable ? (selected ? "❯ " : "  ") : "").forgroundColor(markerColor)

        let base = HStack(alignment: .top, spacing: 0, children: [marker, rowContent(element)], header: "")
        if selected && focused { return base.forgroundColor(.cyan).bold() }
        if selected            { return base.forgroundColor(.eight_bit(245)) }
        return base
    }
}
