//
//  ZStack.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/11/08.
//

/// A view that overlays its children, aligning them in both axes,
/// mirroring SwiftUI's `ZStack`.
///
/// The stack is as large as its largest child; every child is positioned by
/// `alignment` inside that footprint and later children paint over earlier
/// ones. Cells a child never writes stay transparent, so a small child over
/// a large one shows the large one around it.
///
/// ```swift
/// ZStack(alignment: .bottomTrailing) {
///     Dashboard()
///     Text(" Saved ").background(.green).foregroundStyle(.black)   // a toast
/// }
/// ```
public struct ZStack: View, @unchecked Sendable {
    private let children: [any View]
    private let alignment: Alignment
    private let style: TextStyle

    /// Creates a z-stack with the given alignment.
    /// - Parameters:
    ///   - alignment: Where each child sits inside the stack. Defaults to `.center`.
    ///   - content: A ``ViewBuilder`` closure that produces the child views.
    public init<Content: View>(alignment: Alignment = .center, @ViewBuilder content: () -> Content) {
        self.alignment = alignment
        self.children = content()._flattenedChildren()
        self.style = .plain
    }

    init(alignment: Alignment, children: [any View], style: TextStyle) {
        self.alignment = alignment
        self.children = children
        self.style = style
    }

    /// `ZStack` is a layout primitive: it lowers directly via ``makeNode()``
    /// and has no body.
    public typealias Body = Never

    @_spi(RenderingInternals)
    public func applyingStyle(_ style: TextStyle) -> ZStack {
        ZStack(alignment: alignment, children: children, style: self.style.inheriting(style))
    }

    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        let node = RenderNode.zstack(alignment: alignment, children: children.enumerated().map { $1.lowered(at: $0) })
        return style.isPlain ? node : node.applyingStyle(style)
    }
}

extension ZStack: _StyleCarryingView {}

// MARK: - overlay / background(content:)

/// Lays a secondary view over (or behind) the modified view's footprint.
struct LayerModifier: ViewModifier {
    let alignment: Alignment
    let layer: any View
    let behind: Bool

    func node(for content: RenderNode) -> RenderNode {
        .overlay(alignment: alignment, base: content, layer: layer.lowered(at: 1), behind: behind)
    }
}

public extension View {
    /// Layers a view in front of this one, mirroring SwiftUI's
    /// `overlay(alignment:content:)`.
    ///
    /// The overlay is positioned by `alignment` inside this view's footprint
    /// and does not change the view's size — the place for a toast or a
    /// status badge in a corner.
    ///
    /// ```swift
    /// MainView()
    ///     .overlay(alignment: .bottomTrailing) {
    ///         if let toast { Text(" \(toast) ").background(.green).foregroundStyle(.black) }
    ///     }
    /// ```
    func overlay<Content: View>(alignment: Alignment = .center, @ViewBuilder content: () -> Content) -> some View {
        modifier(LayerModifier(alignment: alignment, layer: content(), behind: false))
    }

    /// Layers a view behind this one, mirroring SwiftUI's
    /// `background(alignment:content:)`. The background view is positioned
    /// by `alignment` inside this view's footprint; use ``background(_:)``
    /// with a ``Color`` to fill the footprint.
    func background<Content: View>(alignment: Alignment = .center, @ViewBuilder content: () -> Content) -> some View {
        modifier(LayerModifier(alignment: alignment, layer: content(), behind: true))
    }
}

// MARK: - safeAreaInset

/// Pins a view to one edge of the available space around the modified
/// content, mirroring SwiftUI's `safeAreaInset(edge:alignment:spacing:content:)`.
///
/// The inset's content is lowered first, while the environment is adjusted,
/// so the modified content lays out in the rows (or columns) that remain.
final class SafeAreaInsetModifier: ViewModifier {
    let edge: Edge
    let spacing: Int
    let inset: any View
    /// The inset node, lowered once per frame in ``adjustEnvironment(_:)``
    /// and placed in ``node(for:)``.
    private var insetNode: RenderNode = .empty
    private var insetSize: Size = .zero

    init(edge: Edge, spacing: Int, inset: any View) {
        self.edge = edge
        self.spacing = spacing
        self.inset = inset
    }

    func adjustEnvironment(_ values: inout EnvironmentValues) {
        insetNode = inset.lowered(at: 1)
        insetSize = NodeLayout.measure(insetNode, proposedWidth: values.maxWidth)
        switch edge {
        case .top, .bottom:
            values.maxHeight = Swift.max(1, values.maxHeight - insetSize.height - spacing)
        case .leading, .trailing:
            values.maxWidth = Swift.max(1, values.maxWidth - insetSize.width - spacing)
        }
    }

    func node(for content: RenderNode) -> RenderNode {
        let gap: RenderNode = spacing > 0 ? .spacer(style: .plain, minLength: spacing) : .empty
        switch edge {
        case .bottom:
            // A flexible spacer pushes the inset to the last available row.
            return .vstack(alignment: .leading, spacing: 0, children: [content, .spacer(style: .plain, minLength: spacing), insetNode])
        case .top:
            return .vstack(alignment: .leading, spacing: 0, children: [insetNode, gap, content])
        case .leading:
            return .hstack(alignment: .top, spacing: spacing, children: [insetNode, content])
        case .trailing:
            return .hstack(alignment: .top, spacing: spacing, children: [content, .spacer(style: .plain, minLength: 0), insetNode])
        }
    }
}

public extension View {
    /// Shows `content` along `edge` of the space this view is given, and
    /// lays this view out in what remains — mirroring SwiftUI's
    /// `safeAreaInset(edge:alignment:spacing:content:)`.
    ///
    /// With `.bottom`, the inset sits on the last row of the available
    /// height whatever the content's own height — the natural home for a
    /// key-hint line in a full-screen app:
    ///
    /// ```swift
    /// RootView()
    ///     .safeAreaInset(edge: .bottom) {
    ///         Text(" j/k move  ⏎ open  q quit ").foregroundStyle(.secondary)
    ///     }
    /// ```
    ///
    /// `alignment` is accepted for SwiftUI parity; the terminal inset spans
    /// the edge it is placed on.
    func safeAreaInset<Content: View>(edge: Edge, alignment: Alignment = .center, spacing: Int = 0, @ViewBuilder content: () -> Content) -> some View {
        modifier(SafeAreaInsetModifier(edge: edge, spacing: spacing, inset: content()))
    }
}
