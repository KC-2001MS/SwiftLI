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
        let markerColor: Color = selected ? (focused ? .cyan : .eightBit(245)) : .eightBit(240)
        let marker = Text(content: selectable ? (selected ? "❯ " : "  ") : "").foregroundStyle(markerColor)

        let base = HStack(alignment: .top, spacing: 0, children: [marker, row], style: .plain)
        if selected && focused { return base.foregroundStyle(.cyan).bold() }
        if selected            { return base.foregroundStyle(.eightBit(245)) }
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

/// The sidebar list style — the selected row is filled across the list's
/// width with the selection colour (cyan with black text while focused, a
/// dim grey when not), the way a sidebar highlights its current item.
/// Equivalent to ``ListStyle/sidebar``.
public struct SidebarListStyle: ListStyle {
    /// Creates a sidebar list style.
    public init() {}

    /// Returns a view that stacks the rows, filling the selected one.
    public func makeBody(configuration: ListStyleConfiguration) -> some View {
        var rowViews: [any View] = []
        for (index, row) in configuration.rows.enumerated() {
            let selected = configuration.isSelectable && index == configuration.selectedIndex
            // The spacer stretches the fill to the list's full width.
            let line = HStack(alignment: .top, spacing: 0, children: [Text(content: " "), row, Spacer(minLength: 1)], style: .plain)
            if selected && configuration.isFocused {
                rowViews.append(line.background(.cyan).foregroundStyle(.black))
            } else if selected {
                rowViews.append(line.background(.eightBit(240)))
            } else {
                rowViews.append(line)
            }
        }
        return VStack(alignment: .leading, spacing: 0, children: rowViews)
    }
}

public extension ListStyle where Self == SidebarListStyle {
    /// The sidebar list style: the selected row filled across the width.
    static var sidebar: Self { .init() }
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
/// (<kbd>Page Up</kbd>/<kbd>Page Down</kbd> move a screenful,
/// <kbd>Home</kbd>/<kbd>End</kbd> jump to the ends, <kbd>Return</kbd> calls
/// the enclosing ``View/onSubmit(_:)``), and <kbd>Tab</kbd> moves focus on
/// to the next control. Constrain the height with `.frame(height:)` and, when
/// the rows do not fit, the list scrolls so the selected row — however many
/// lines it spans — stays entirely in view, drawing a scrollbar to the right.
///
/// ```swift
/// @State var selected: Item.ID?
///
/// var body: some View {
///     List(items, selection: $selected) { item in
///         ItemRow(item: item)              // rows may span several lines
///     }
///     .onSubmit { open(selected) }
///     .frame(height: 8)
/// }
/// ```
///
/// Without a `selection` the list is a plain, non-focusable column of rows.
/// The selected row's look comes from the ``ListStyle`` (``PlainListStyle``
/// marks it with `❯`, ``SidebarListStyle`` fills it).
public struct List<Data: RandomAccessCollection, RowContent: View>: View, @unchecked Sendable {
    private let textStyle: TextStyle
    /// An identity given explicitly, or `nil` to derive one from the label.
    let explicitID: String?
    /// The identity used when none is given — the label, made unique per
    /// position inside a session (see ``ControlIdentity``).
    let fallbackID: String
    /// The identity the control registers under.
    var id: String { ControlIdentity.resolve(explicitID, default: fallbackID) }
    private let data: Data
    private let selection: Binding<Int?>?
    private let rowContent: (Data.Element) -> RowContent
    /// The explicitly applied style, or `nil` to resolve from the environment.
    private let style: AnyListStyle?
    /// The `onReachEnd` hook: how close to the end the selection must come,
    /// and what to run then.
    private var reachEnd: (within: Int, action: @Sendable () -> Void)? = nil

    /// Creates a list over `data`, selecting rows by index.
    ///
    /// - Parameters:
    ///   - data: The rows' backing collection.
    ///   - selection: A bound selected-row index; pass `nil` for a static list.
    ///   - id: A stable identity for focus/scroll state.
    ///   - rowContent: Builds the view for one element.
    public init(
        _ data: Data,
        selection: Binding<Int?>? = nil,
        id: String? = nil,
        @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent
    ) {
        self.textStyle = .plain
        self.explicitID = id
        self.fallbackID = "List"
        self.data = data
        self.selection = selection
        self.rowContent = rowContent
        self.style = nil
    }

    /// Creates a list over `Identifiable` data, selecting rows by the
    /// element's id — SwiftUI's `List(_:selection:rowContent:)`.
    ///
    /// The binding holds the selected element's `id` (or `nil`); it stays
    /// valid when rows are inserted or removed before the selected one.
    public init(
        _ data: Data,
        selection: Binding<Data.Element.ID?>,
        id: String? = nil,
        @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent
    ) where Data.Element: Identifiable, Data.Element.ID: Sendable {
        // The ids are snapshotted per render (the list is rebuilt whenever
        // the data changes), which keeps the closures `Sendable`.
        let ids = data.map(\.id)
        let indexBinding = Binding<Int?>(
            get: {
                guard let selected = selection.wrappedValue else { return nil }
                return ids.firstIndex(of: selected)
            },
            set: { index in
                guard let index, index >= 0, index < ids.count else {
                    selection.wrappedValue = nil
                    return
                }
                selection.wrappedValue = ids[index]
            }
        )
        self.init(data, selection: indexBinding, id: id, rowContent: rowContent)
    }

    init(textStyle: TextStyle, explicitID: String?, fallbackID: String, data: Data, selection: Binding<Int?>?, rowContent: @escaping (Data.Element) -> RowContent, style: AnyListStyle? = nil, reachEnd: (within: Int, action: @Sendable () -> Void)? = nil) {
        self.textStyle = textStyle
        self.explicitID = explicitID
        self.fallbackID = fallbackID
        self.data = data
        self.selection = selection
        self.rowContent = rowContent
        self.style = style
        self.reachEnd = reachEnd
    }

    /// The rows as decorated by the resolved ``ListStyle``, scrolled to the
    /// selection when a height bounds them.
    ///
    /// Reading `body` composes the rows without registering the list;
    /// ``makeNode()`` is what measures the rows, follows the selection and
    /// registers the control.
    public var body: some View {
        styledRows
    }

    /// `.frame(height:)` pins `maxHeight`, bounding the visible rows.
    private var resolvedHeight: Int {
        EnvironmentStack.current.maxHeight
    }

    /// Only a selectable list takes focus.
    private var isFocused: Bool {
        selection != nil && FocusCoordinator.shared.isFocused(id)
    }

    /// Every row plus the selection state, handed to the active style, which
    /// returns the stacked, decorated rows.
    private var styledRows: AnyView {
        // Nearest wins: instance style, then subtree environment, then default.
        let resolvedStyle = style ?? EnvironmentStack.current.listStyle ?? AnyListStyle(PlainListStyle())
        return resolvedStyle.makeBody(configuration: ListStyleConfiguration(
            rows: data.map { AnyView(erasing: rowContent($0)) },
            selectedIndex: selection?.wrappedValue,
            isFocused: isFocused,
            isSelectable: selection != nil
        ))
    }

    @_spi(RenderingInternals)
    public func applyingStyle(_ style: TextStyle) -> Self {
        List(textStyle: textStyle.inheriting(style), explicitID: explicitID, fallbackID: fallbackID, data: data, selection: selection, rowContent: rowContent, style: self.style, reachEnd: reachEnd)
    }

    /// The per-row nodes of the style's stacked rows, when the style emitted
    /// one node per row (the built-in styles do); `nil` for a style that
    /// adds chrome rows, which then falls back to one line per row.
    private static func rowNodes(of node: RenderNode, count: Int) -> [RenderNode]? {
        switch node {
        case .vstack(_, _, let children), .group(let children):
            let flat = NodeLayout.flatten(children)
            return flat.count == count ? flat : nil
        case .background(_, let child), .control(_, let child):
            return rowNodes(of: child, count: count)
        default:
            return nil
        }
    }

    /// Lowers the rows, measures them, scrolls the viewport to keep the
    /// selected row entirely visible, and registers the list for keyboard
    /// handling — as the list's pointer footprint when selectable; a static
    /// list stays inert.
    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        let coordinator = FocusCoordinator.shared
        if let selection {
            // Claim the list's place in the focus ring before the rows are
            // composed, so the first frame already shows it focused; the
            // registration is completed with the measured geometry below.
            coordinator.registerList(id: id, selection: selection, count: data.count, viewportRows: nil)
        }
        let rowsNode = styledRows.lowered(at: 0)
        let count = data.count
        let viewport = resolvedHeight
        let environment = EnvironmentStack.current
        let visibility = environment.verticalScrollIndicatorVisibility
        let bar: ScrollBar? = visibility.showsIndicator ? ScrollView.scrollBar(focused: isFocused) : nil
        // The rows are measured at the width they will be laid out in:
        // the available width less the scrollbar's column.
        let contentWidth = NodeLayout.scrollContentProposal(environment.maxWidth, bar: bar, width: environment.maxWidth)

        var node = rowsNode
        if let selection {
            // One line per row unless the rows are measurable individually.
            let heights = Self.rowNodes(of: rowsNode, count: count)?.map {
                Swift.max(1, NodeLayout.measure($0, axis: .vertical, proposedWidth: contentWidth).height)
            }
            var rowStarts: [Int] = []
            var total = 0
            for height in heights ?? Array(repeating: 1, count: count) {
                rowStarts.append(total)
                total += height
            }
            let scrolls = total > viewport && viewport > 0
            let selected = selection.wrappedValue
            let pageSize = heights.map { heights -> Int in
                let average = Swift.max(1, total / Swift.max(1, heights.count))
                return Swift.max(1, viewport / average)
            } ?? viewport

            if scrolls {
                // Follow the selection only when it moved (or the offset no
                // longer fits), so a wheel scroll is not undone by an
                // unrelated redraw.
                var offset = coordinator.listOffset(for: id)
                let maxOffset = Swift.max(0, total - viewport)
                let changed = coordinator.listSelectionChanged(selected, for: id)
                if changed, let selected, selected >= 0, selected < rowStarts.count {
                    let start = rowStarts[selected]
                    let end = start + (heights?[selected] ?? 1)
                    if start < offset { offset = start }
                    else if end > offset + viewport { offset = end - viewport }
                }
                offset = Swift.min(Swift.max(offset, 0), maxOffset)
                coordinator.setListOffset(offset, for: id)
                node = .scroll(offset: offset, height: viewport, bar: bar, width: environment.maxWidth, child: rowsNode)
            } else {
                coordinator.setListOffset(0, for: id)
                _ = coordinator.listSelectionChanged(selected, for: id)
            }

            coordinator.registerList(
                id: id,
                selection: selection,
                count: count,
                viewportRows: scrolls ? viewport : nil,
                rowStarts: heights == nil ? nil : rowStarts,
                pageSize: pageSize,
                onSubmit: environment.submitAction
            )
            KeyInputRouter.shared.ensureStarted()

            // Near the end: let the app load more rows, once per row count.
            if let reachEnd, let selected, count > 0, selected >= count - Swift.max(1, reachEnd.within),
               coordinator.listShouldFireReachEnd(count: count, for: id) {
                let action = reachEnd.action
                DispatchQueue.main.async { action() }
            }
        }

        let styled = textStyle.isPlain ? node : node.applyingStyle(textStyle)
        return selection != nil ? styled.asControl(id: id) : styled
    }

    /// Sets the style used to compose this list's rows.
    ///
    /// - Parameter newStyle: A value conforming to ``ListStyle``.
    public func listStyle(_ newStyle: some ListStyle) -> Self {
        List(textStyle: textStyle, explicitID: explicitID, fallbackID: fallbackID, data: data, selection: selection, rowContent: rowContent, style: AnyListStyle(newStyle), reachEnd: reachEnd)
    }

    /// Runs `action` when the selection comes within `rows` rows of the
    /// last row — the hook for loading the next page of data.
    ///
    /// The action runs once per row count: after it appends more rows the
    /// list arms itself again for the new end.
    ///
    /// ```swift
    /// List(model.items, selection: $selection) { ItemRow(item: $0) }
    ///     .onReachEnd { Task { await model.loadMore() } }
    /// ```
    public func onReachEnd(within rows: Int = 1, perform action: @escaping @Sendable () -> Void) -> Self {
        List(textStyle: textStyle, explicitID: explicitID, fallbackID: fallbackID, data: data, selection: selection, rowContent: rowContent, style: style, reachEnd: (within: rows, action: action))
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
    ///   - id: A stable identity for focus/scroll state.
    ///   - content: A ``ViewBuilder`` whose top-level views become the rows.
    init(
        selection: Binding<Int?>? = nil,
        id: String? = nil,
        @ViewBuilder content: () -> some View
    ) {
        let rows = content()._flattenedChildren().map { AnyView(erasing: $0) }
        self.init(rows, selection: selection, id: id) { $0 }
    }
}

// MARK: - onSubmit

private struct SubmitActionKey: EnvironmentKey {
    static var defaultValue: (() -> Void)? { nil }
}

extension EnvironmentValues {
    /// The action the enclosing ``View/onSubmit(_:)`` declared, which a
    /// ``List`` runs on <kbd>Return</kbd> and a ``TextField`` without its own
    /// `onSubmit:` runs on <kbd>Return</kbd>.
    var submitAction: (() -> Void)? {
        get { self[SubmitActionKey.self] }
        set { self[SubmitActionKey.self] = newValue }
    }
}

public extension View {
    /// Adds an action to perform when a control in this view submits —
    /// <kbd>Return</kbd> on a selectable ``List`` or ``Table``, or in a
    /// ``TextField`` — mirroring SwiftUI's `onSubmit(_:)`.
    ///
    /// ```swift
    /// List(items, selection: $selection) { ItemRow(item: $0) }
    ///     .onSubmit { if let id = selection { path.append(.detail(id)) } }
    /// ```
    func onSubmit(_ action: @escaping () -> Void) -> some View {
        environment(\.submitAction, action)
    }
}
