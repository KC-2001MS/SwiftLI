//
//  HStack.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2024/05/27.
//

/// The vertical alignment of children within an ``HStack``.
public enum VerticalAlignment: Sendable, Equatable {
    /// Align children to the top row of the stack.
    case top
    /// Align children to the bottom row of the stack.
    case bottom
}

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
    private let header: String

    /// Creates an HStack with the given children and optional spacing.
    /// - Parameters:
    ///   - alignment: Vertical alignment when children have different heights. Defaults to `.top`.
    ///   - spacing: Number of space columns between each child. Defaults to `0`.
    ///   - content: A ``ViewBuilder`` closure that produces the child views.
    public init(
        alignment: VerticalAlignment = .top,
        spacing: Int = 0,
        @ViewBuilder content: () -> Group
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.children = content().contents
        self.header = ""
    }

    init(
        alignment: VerticalAlignment,
        spacing: Int,
        children: [any View],
        header: String
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.children = children
        self.header = header
    }

    public var body: some View { Group(contents: []) }

    @_spi(RenderingInternals)
    public func addHeader(_ newHeader: String) -> HStack {
        HStack(alignment: alignment, spacing: spacing, children: children, header: newHeader + header)
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
        return header.isEmpty ? node : node.applyingHeader(header)
    }
}
