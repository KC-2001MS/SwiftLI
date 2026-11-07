//
//  ScrollView.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/07.
//

// MARK: - Axis

/// The two layout axes, mirroring SwiftUI's `Axis` type.
public struct Axis: Sendable {
    /// A set of axes. Use `.vertical`, `.horizontal`, or both
    /// (`[.vertical, .horizontal]`).
    public struct Set: OptionSet, Sendable {
        public let rawValue: Int8
        public init(rawValue: Int8) { self.rawValue = rawValue }
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
/// With the pointer, the vertical wheel scrolls the vertical viewport under
/// it and, as in SwiftUI, never a horizontal one. A horizontal viewport
/// follows a horizontal wheel or swipe where the terminal reports one, and
/// Shift + wheel everywhere (Terminal.app reports vertical wheel events
/// only, so Shift + wheel is its horizontal gesture).
///
/// A proportional scrollbar is drawn as a solid strip of whole cells. For
/// vertical viewports it is pinned to the trailing edge; for horizontal
/// viewports it runs along the bottom edge. It is hidden when everything
/// already fits or when ``View/scrollIndicators(_:axes:)`` hides it for the
/// axis. Drag its thumb to
/// scroll; a press on the track jumps the thumb to the pointer.
///
/// Like SwiftUI's, the viewport fills the space it is given: its extent in
/// the scroll axis defaults to the full available space, and while it
/// scrolls it also spans the available space in the other axis so the
/// scrollbar sits at that edge — the trailing column for a vertical
/// viewport, the bottom row for a horizontal one. Use `.frame` to size it:
///
/// ```swift
/// // Vertical: 10-row window over a tall list; the bar sits at the
/// // trailing edge of the available width.
/// ScrollView {
///     ForEach(0..<100) { i in Text("Row \(i)") }
/// }
/// .frame(height: 10)
///
/// // Horizontal: 40-column window over a one-row strip; the bar sits on the
/// // second row.
/// ScrollView(.horizontal) {
///     HStack { /* wide content */ }
/// }
/// .frame(width: 40, height: 2)
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

    /// Creates a self-scrolling viewport along `axes`, mirroring SwiftUI's
    /// `ScrollView(_:content:)`.
    ///
    /// The viewport fills the available space in the scroll axis by default,
    /// and the available space in the other axis while it scrolls (that is
    /// where its scrollbar sits). Size it with `.frame(height:)` for a
    /// vertical viewport or `.frame(width:height:)` for a horizontal one.
    /// Hide the scrollbar with ``View/scrollIndicators(_:axes:)``.
    ///
    /// Each call site is its own scroll view: focus and scroll offset are
    /// tracked per source location, so several scroll views on one screen
    /// keep independent positions.
    ///
    /// - Parameters:
    ///   - axes: The scroll axis. Pass `.vertical` (the default) or
    ///     `.horizontal`.
    ///   - content: A ``ViewBuilder`` closure producing the scrolled content.
    public init<Content: View>(
        _ axes: Axis.Set = .vertical,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        @ViewBuilder content: () -> Content
    ) {
        self.init(axes, showsIndicators: true, id: "\(fileID):\(line):\(column)", content: content)
    }

    /// Creates a self-scrolling viewport that can hide its scrollbar.
    ///
    /// Like SwiftUI, this initializer is deprecated in favour of
    /// ``View/scrollIndicators(_:axes:)``, which also reaches ``List``,
    /// ``Table`` and ``TextEditor``.
    @available(*, deprecated, message: "Use the scrollIndicators(_:axes:) modifier instead.")
    public init<Content: View>(
        _ axes: Axis.Set = .vertical,
        showsIndicators: Bool,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        @ViewBuilder content: () -> Content
    ) {
        self.init(axes, showsIndicators: showsIndicators, id: "\(fileID):\(line):\(column)", content: content)
    }

    /// Creates a self-scrolling viewport with an explicit identity. Internal:
    /// the public initializers derive the identity from the call site.
    init<Content: View>(_ axes: Axis.Set, showsIndicators: Bool, id: String, @ViewBuilder content: () -> Content) {
        self.extent = nil
        self.isHorizontal = axes.isHorizontal
        self.showsIndicators = showsIndicators
        self.content = content()._flattenedChildren()
        self.driver = .managed(id: id)
    }

    /// Creates a viewport whose offset is controlled by an enclosing view.
    ///
    /// The scroll view does **not** register its own scroll control here — the
    /// caller (``List``/``Table``) already owns focus and computes the offset —
    /// so this simply windows and draws the scrollbar. Internal on purpose.
    init(height: Int, offset: Int, focused: Bool, content: [any View]) {
        self.extent = height
        self.isHorizontal = false
        self.showsIndicators = true
        self.content = content
        self.driver = .controlled(offset: offset, focused: focused)
    }

    /// `ScrollView` is a layout primitive: it lowers directly via
    /// ``makeNode()`` and has no body.
    public typealias Body = Never

    /// A style applied to the whole view, cascaded onto the lowered content.
    var style: TextStyle = .plain

    @_spi(RenderingInternals)
    public func applyingStyle(_ style: TextStyle) -> Self {
        var copy = self
        copy.style = self.style.inheriting(style)
        return copy
    }

    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        let childNode = Group(contents: content).lowered(at: 0)

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
            let environment = EnvironmentStack.current
            let contentProposal = isHorizontal ? nil : NodeLayout.scrollContentProposal(environment.maxWidth, bar: ScrollView.scrollBar(focused: false), width: environment.maxWidth)
            let contentExtent = isHorizontal
                ? NodeLayout.measure(childNode).width
                : NodeLayout.measure(childNode, proposedWidth: contentProposal).height
            let coordinator = FocusCoordinator.shared
            coordinator.registerScroll(id: id, viewportHeight: resolvedExtent, contentHeight: contentExtent, isHorizontal: isHorizontal)
            KeyInputRouter.shared.ensureStarted()
            if !isHorizontal {
                // A `scrollTo(_:anchor:)` requested through the enclosing
                // ScrollViewReader's proxy.
                if let reader = environment.scrollReaderID, let request = ScrollTargetRegistry.shared.take(reader: reader),
                   let range = NodeLayout.rowRange(ofControl: ScrollTargetRegistry.markerID(for: request.target), in: childNode, proposedWidth: contentProposal) {
                    let anchorY = request.anchor?.y ?? 0
                    let target = range.lowerBound - Int((Double(resolvedExtent - range.count) * anchorY).rounded())
                    coordinator.setScrollOffset(target, for: id)
                }
                // Keep a focused child in view when focus moves to it (and
                // only then, so a wheel scroll is not undone by a redraw).
                if let focusedChild = coordinator.focused, focusedChild != id,
                   coordinator.scrollFocusChanged(focusedChild, for: id),
                   let range = NodeLayout.rowRange(ofControl: focusedChild, in: childNode, proposedWidth: contentProposal) {
                    let current = coordinator.scrollOffset(for: id)
                    if range.lowerBound < current {
                        coordinator.setScrollOffset(range.lowerBound, for: id)
                    } else if range.upperBound > current + resolvedExtent {
                        coordinator.setScrollOffset(range.upperBound - resolvedExtent, for: id)
                    }
                }
            }
            offset = coordinator.scrollOffset(for: id)
            focused = coordinator.isFocused(id)
        case .controlled(let o, let f):
            offset = o
            focused = f
        }

        // Both the initializer and `.scrollIndicators(_:axes:)` can hide the
        // bar; it is drawn only when neither does.
        let environment = EnvironmentStack.current
        let visibility = isHorizontal
            ? environment.horizontalScrollIndicatorVisibility
            : environment.verticalScrollIndicatorVisibility
        let bar = showsIndicators && visibility.showsIndicator ? Self.scrollBar(focused: focused) : nil
        let node: RenderNode
        if isHorizontal {
            // The horizontal bar sits on the bottom edge of the viewport.
            // Pin the scrollbar to the bottom edge of the rows this viewport is
            // allotted, as the vertical viewport pins its bar to the far column.
            node = .hscroll(offset: offset, extent: resolvedExtent, bar: bar, height: EnvironmentStack.current.maxHeight, child: childNode)
        } else {
            // Pin the scrollbar to the far edge of the columns this viewport is
            // allotted, macOS-style, instead of hugging the content's own width.
            node = .scroll(offset: offset, height: resolvedExtent, bar: bar, width: EnvironmentStack.current.maxWidth, child: childNode)
        }
        // Only a self-managed viewport is a control of its own; a controlled
        // one belongs to its owner (List/Table), which wraps the node itself.
        let styledNode = style.isPlain ? node : node.applyingStyle(style)
        if case .managed(let id) = driver {
            return styledNode.asControl(id: id)
        }
        return styledNode
    }

    /// The scrollbar palette: a cyan thumb while focused (dim white otherwise)
    /// over a dark-grey track. Shared so ``List`` and ``Table`` (which compose
    /// a controlled ``ScrollView``) get an identical scrollbar.
    static func scrollBar(focused: Bool) -> ScrollBar {
        ScrollBar(
            thumb: focused ? .cyan : .eightBit(245),
            track: .eightBit(238)
        )
    }
}
