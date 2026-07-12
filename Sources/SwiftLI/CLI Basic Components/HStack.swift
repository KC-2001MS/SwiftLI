//
//  HStack.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2024/05/27.
//

/// A view that arranges its children in a horizontal line.
///
/// `HStack` measures each child view, then draws them side-by-side into a
/// ``TerminalCanvas``, with an optional gap between children.
///
/// ```swift
/// HStack {
///     Text("Left").forgroundColor(.red)
///     Text("  |  ")
///     Text("Right").forgroundColor(.blue)
/// }
/// .render()
/// ```
///
/// When children have different heights, use `alignment` to control vertical
/// positioning:
/// - `.top` (default): all children start at the same row.
/// - `.bottom`: all children end at the same row.
public struct HStack: View, @unchecked Sendable {
    private let children: [any View]
    private let spacing: Int
    private let alignment: VerticalAlignment
    private let style: TextStyle

    /// Creates an HStack with the given children and optional spacing.
    /// - Parameters:
    ///   - alignment: Vertical alignment when children have different heights. Defaults to `.top`.
    ///   - spacing: Number of space columns between each child. Defaults to `0`.
    ///   - content: A ``ViewBuilder`` closure that produces the child views.
    public init<Content: View>(
        alignment: VerticalAlignment = .top,
        spacing: Int = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.children = content()._flattenedChildren()
        self.style = .plain
    }

    init(
        alignment: VerticalAlignment,
        spacing: Int,
        children: [any View],
        style: TextStyle
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.children = children
        self.style = style
    }

    public var body: some View {
        EmptyView()
    }

    @_spi(RenderingInternals)
    public func applyingStyle(_ style: TextStyle) -> HStack {
        HStack(alignment: alignment, spacing: spacing, children: children, style: self.style.inheriting(style))
    }

    /// Lowers this stack into an ``RenderNode/hstack`` node.
    ///
    /// All flattening of transparent ``Group`` children, alignment, and the
    /// direction-adaptive behaviour of ``Spacer`` and ``Divider`` is handled
    /// downstream by the layout engine — which is what lets arbitrary nesting
    /// like `HStack > VStack > HStack` resolve through simple recursion.
    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        let node = RenderNode.hstack(
            alignment: alignment,
            spacing: spacing,
            children: children.map { $0.makeNode() }
        )
        return style.isPlain ? node : node.applyingStyle(style)
    }
}
