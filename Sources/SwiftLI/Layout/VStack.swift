//
//  VStack.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2024/05/27.
//

/// The horizontal alignment of children within a ``VStack``.
public enum HorizontalAlignment: Sendable, Equatable {
    /// Align children to the leading (left) edge of the stack.
    case leading
    /// Align children to the trailing (right) edge of the stack.
    case trailing
}

/// A view that arranges its children in a vertical line.
///
/// `VStack` measures each child view, then draws them stacked top-to-bottom
/// into a ``TerminalCanvas``, with an optional gap between children.
///
/// ```swift
/// VStack {
///     Text("Line 1").forgroundColor(.red)
///     Text("Line 2").forgroundColor(.blue)
///     Text("Line 3").bold()
/// }
/// .render()
/// ```
///
/// When children have different widths, use `alignment` to control horizontal
/// positioning:
/// - `.leading` (default): all children are left-aligned.
/// - `.trailing`: all children are right-aligned.
public struct VStack: View, @unchecked Sendable {
    private let children: [any View]
    private let spacing: Int
    private let alignment: HorizontalAlignment
    private let header: String

    /// Creates a VStack with the given children and optional spacing.
    /// - Parameters:
    ///   - alignment: Horizontal alignment when children have different widths. Defaults to `.leading`.
    ///   - spacing: Number of blank rows between each child. Defaults to `0`.
    ///   - content: A ``ViewBuilder`` closure that produces the child views.
    public init(
        alignment: HorizontalAlignment = .leading,
        spacing: Int = 0,
        @ViewBuilder content: () -> Group
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.children = content().contents
        self.header = ""
    }

    /// Creates a VStack directly from an array of views (bypasses ``ViewBuilder``).
    /// Used internally to wrap top-level body arrays in an implicit root VStack.
    init(
        alignment: HorizontalAlignment = .leading,
        spacing: Int = 0,
        children: [any View]
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.children = children
        self.header = ""
    }

    init(
        alignment: HorizontalAlignment,
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
    public func addHeader(_ newHeader: String) -> VStack {
        VStack(alignment: alignment, spacing: spacing, children: children, header: newHeader + header)
    }

    /// Lowers this stack into an ``RenderNode/vstack`` node.
    ///
    /// Flattening of transparent ``Group`` children, leading/trailing
    /// alignment, and horizontal ``Divider`` spanning are all resolved by the
    /// layout engine, so nested stacks compose without special cases here.
    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        let node = RenderNode.vstack(
            alignment: alignment,
            spacing: spacing,
            children: children.map { $0.makeNode() }
        )
        return header.isEmpty ? node : node.applyingHeader(header)
    }
}
