//
//  ScrollView.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/07.
//

/// A fixed-height viewport that scrolls a taller stack of content vertically.
///
/// `ScrollView` lays its content out in full, then shows only a `height`-row
/// window of it. While a reactive runtime is active and the scroll view is
/// focused, the arrow keys move the window: <kbd>↑</kbd>/<kbd>↓</kbd> by one
/// line, <kbd>Space</kbd> by a page, and <kbd>Home</kbd>/<kbd>End</kbd> jump to
/// the ends. <kbd>Tab</kbd> / <kbd>Shift-Tab</kbd> move focus to the next
/// control, so a scroll view participates in the same focus ring as text fields
/// and toggles.
///
/// A proportional scrollbar is drawn to the right of the content (hidden when
/// everything already fits, or when `showsIndicators` is `false`).
///
/// ```swift
/// ScrollView(height: 10) {
///     ForEach(0..<100) { i in
///         Text("Row \(i)")
///     }
/// }
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

    private let height: Int
    private let showsIndicators: Bool
    private let content: [any View]
    private let driver: Driver

    /// Creates a self-scrolling vertical viewport.
    /// - Parameters:
    ///   - height: The number of rows visible at once.
    ///   - showsIndicators: Whether to draw the scrollbar. Defaults to `true`.
    ///   - id: A stable identity used to track focus and scroll offset.
    ///   - content: A ``ViewBuilder`` closure producing the scrolled content.
    public init(
        height: Int,
        showsIndicators: Bool = true,
        id: String = "ScrollView",
        @ViewBuilder content: () -> Group
    ) {
        self.height = height
        self.showsIndicators = showsIndicators
        self.content = content().contents
        self.driver = .managed(id: id)
    }

    /// Creates a viewport whose offset is controlled by an enclosing view.
    ///
    /// The scroll view does **not** register its own scroll control here — the
    /// caller (``List``/``Table``) already owns focus and computes the offset —
    /// so this simply windows and draws the scrollbar. Internal on purpose.
    init(height: Int, offset: Int, focused: Bool, showsIndicators: Bool, content: [any View]) {
        self.height = height
        self.showsIndicators = showsIndicators
        self.content = content
        self.driver = .controlled(offset: offset, focused: focused)
    }

    public var body: some View { Group(contents: []) }

    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        let childNode = Group(contents: content).makeNode()

        let offset: Int
        let focused: Bool
        switch driver {
        case .managed(let id):
            let contentHeight = NodeLayout.measure(childNode).height
            FocusCoordinator.shared.registerScroll(id: id, viewportHeight: height, contentHeight: contentHeight, onSubmit: nil)
            KeyInputRouter.shared.ensureStarted()
            offset = FocusCoordinator.shared.scrollOffset(for: id)
            focused = FocusCoordinator.shared.isFocused(id)
        case .controlled(let o, let f):
            offset = o
            focused = f
        }

        let thumb = showsIndicators ? Self.bar("█", focused: focused) : nil
        let track = showsIndicators ? Self.bar("░", focused: focused) : nil
        return .scroll(offset: offset, height: height, thumb: thumb, track: track, child: childNode)
    }

    /// A single pre-styled scrollbar glyph: cyan when focused, dim otherwise.
    /// Shared so ``List`` and ``Table`` (which compose a controlled ``ScrollView``)
    /// get an identical scrollbar.
    static func bar(_ glyph: String, focused: Bool) -> String {
        let color = focused ? "\u{001B}[36m" : "\u{001B}[38;5;240m"
        return color + glyph + "\u{001B}[0m"
    }
}
