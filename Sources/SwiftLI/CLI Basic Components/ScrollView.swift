//
//  ScrollView.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/07.
//

// MARK: - Axis

/// The two layout axes, mirroring SwiftUI's `Axis` type.
public struct Axis: Sendable {
    /// A set of axes. Use `.vertical`, `.horizontal`, or both.
    public struct Set: Equatable, Sendable {
        let rawValue: Int
        public static let vertical   = Set(rawValue: 1)
        public static let horizontal = Set(rawValue: 2)
        var isHorizontal: Bool { self == .horizontal }
    }
}

// MARK: - ScrollView

/// A viewport that scrolls its content along one axis.
///
/// `ScrollView` lays its content out in full and shows a windowed portion of
/// it. While a reactive runtime is active and the scroll view is focused, the
/// arrow keys move the window: <kbd>↑</kbd>/<kbd>↓</kbd> by one line for
/// vertical viewports, <kbd>←</kbd>/<kbd>→</kbd> for horizontal ones,
/// <kbd>Space</kbd> by a page, and <kbd>Home</kbd>/<kbd>End</kbd> jump to the
/// ends. <kbd>Tab</kbd> / <kbd>Shift-Tab</kbd> cycle focus.
///
/// A proportional scrollbar is drawn as a solid strip with half-cell
/// precision. For vertical viewports it is pinned to the trailing edge; for
/// horizontal viewports it runs along the bottom edge. It is hidden when
/// everything already fits, or when `showsIndicators` is `false`.
///
/// The viewport size defaults to the full available space in the scroll axis.
/// Use `.frame(height:)` or `.frame(width:)` to constrain it:
///
/// ```swift
/// // Vertical: 10-row window over a tall list.
/// ScrollView {
///     ForEach(0..<100) { i in Text("Row \(i)") }
/// }
/// .frame(height: 10)
///
/// // Horizontal: 40-column window over a wide row.
/// ScrollView(.horizontal) {
///     HStack { /* wide content */ }
/// }
/// .frame(width: 40)
/// ```
///
/// > Note: Identity is keyed by `id`; give each scroll view a distinct `id`
/// > when a screen shows more than one.
public struct ScrollView: View, @unchecked Sendable {
    /// How the viewport's scroll offset is driven.
    private enum Driver {
        /// The scroll view owns its offset: it registers a scroll control in the
        /// focus ring and moves the window itself in response to the arrows.
        case managed(id: String)
        /// The offset (and focus, for the scrollbar tint) is supplied by an
        /// enclosing control. Used by ``List`` and ``Table``, which scroll to
        /// follow their own selection rather than register a second control.
        case controlled(offset: Int, focused: Bool)
    }

    /// The visible extent of the viewport: rows when vertical, columns when
    /// horizontal. `nil` fills the available space in the scroll axis.
    private let extent: Int?
    /// Whether the viewport scrolls horizontally (columns) instead of vertically.
    private let isHorizontal: Bool
    private let showsIndicators: Bool
    private let content: [any View]
    private let driver: Driver

    /// Creates a self-scrolling viewport along `axes`.
    ///
    /// The viewport fills the available space in the scroll axis by default.
    /// Constrain it with `.frame(height:)` for a vertical viewport or
    /// `.frame(width:)` for a horizontal one.
    ///
    /// - Parameters:
    ///   - axes: The scroll axis. Pass `.vertical` (the default) or
    ///     `.horizontal`.
    ///   - showsIndicators: Whether to draw the scrollbar. Defaults to `true`.
    ///   - id: A stable identity used to track focus and scroll offset.
    ///     Defaults to `"ScrollView"` for vertical, `"HScrollView"` for
    ///     horizontal.
    ///   - content: A ``ViewBuilder`` closure producing the scrolled content.
    public init<Content: View>(
        _ axes: Axis.Set = .vertical,
        showsIndicators: Bool = true,
        id: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.extent = nil
        self.isHorizontal = axes.isHorizontal
        self.showsIndicators = showsIndicators
        self.content = content()._flattenedChildren()
        self.driver = .managed(id: id ?? (axes.isHorizontal ? "HScrollView" : "ScrollView"))
    }

    /// Creates a viewport whose offset is controlled by an enclosing view.
    ///
    /// The scroll view does **not** register its own scroll control here — the
    /// caller (``List``/``Table``) already owns focus and computes the offset —
    /// so this simply windows and draws the scrollbar. Internal on purpose.
    init(height: Int, offset: Int, focused: Bool, showsIndicators: Bool, content: [any View]) {
        self.extent = height
        self.isHorizontal = false
        self.showsIndicators = showsIndicators
        self.content = content
        self.driver = .controlled(offset: offset, focused: focused)
    }

    /// The body of the scroll view; rendering is performed by ``makeNode()`` rather than this property.
    public var body: some View {
        EmptyView()
    }

    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        let childNode = Group(contents: content).makeNode()

        // nil extent fills the available space in the scroll axis.
        let resolvedExtent: Int = isHorizontal
            ? (extent ?? EnvironmentStack.current.maxWidth)
            : (extent ?? EnvironmentStack.current.maxHeight)

        let offset: Int
        let focused: Bool
        switch driver {
        case .managed(let id):
            // The focus coordinator tracks a generic scalar offset; for a
            // horizontal viewport the "viewport"/"content" extents are widths.
            let contentExtent = isHorizontal
                ? NodeLayout.measure(childNode).width
                : NodeLayout.measure(childNode).height
            FocusCoordinator.shared.registerScroll(id: id, viewportHeight: resolvedExtent, contentHeight: contentExtent, isHorizontal: isHorizontal)
            KeyInputRouter.shared.ensureStarted()
            offset = FocusCoordinator.shared.scrollOffset(for: id)
            focused = FocusCoordinator.shared.isFocused(id)
        case .controlled(let o, let f):
            offset = o
            focused = f
        }

        let bar = showsIndicators ? Self.scrollBar(focused: focused) : nil
        let node: RenderNode
        if isHorizontal {
            // The horizontal bar sits on the bottom edge of the viewport.
            node = .hscroll(offset: offset, extent: resolvedExtent, bar: bar, child: childNode)
        } else {
            // Pin the scrollbar to the far edge of the columns this viewport is
            // allotted, macOS-style, instead of hugging the content's own width.
            node = .scroll(offset: offset, height: resolvedExtent, bar: bar, width: EnvironmentStack.current.maxWidth, child: childNode)
        }
        // Only a self-managed viewport is a control of its own; a controlled
        // one belongs to its owner (List/Table), which wraps the node itself.
        if case .managed(let id) = driver {
            return node.asControl(id: id)
        }
        return node
    }

    /// The scrollbar palette: a cyan thumb while focused (dim white otherwise)
    /// over a dark-grey track. Shared so ``List`` and ``Table`` (which compose
    /// a controlled ``ScrollView``) get an identical scrollbar.
    static func scrollBar(focused: Bool) -> ScrollBar {
        ScrollBar(
            thumb: focused ? .cyan : .eight_bit(245),
            track: .eight_bit(238)
        )
    }
}
