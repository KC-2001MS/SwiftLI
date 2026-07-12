//
//  Group.swift
//  
//  Created by Keisuke Chinone on 2024/05/27.
//


/// A transparent container that groups multiple views together.
///
/// `Group` is the fundamental container in SwiftLI. It holds a sequence of child
/// views and renders them stacked vertically — one child per row. Unlike
/// ``VStack``, `Group` applies no spacing between children and performs no
/// alignment calculation; it is a simple, zero-overhead wrapper.
///
/// Use `Group` when you need to:
/// - Return multiple views from a single `body` property.
/// - Apply a shared style modifier to several views at once.
/// - Provide a flat list of views to ``VStack`` or ``HStack``.
///
/// ```swift
/// Group {
///     Text("First line").forgroundColor(.red)
///     Text("Second line").forgroundColor(.blue)
///     Text("Third line").bold()
/// }
/// .render()
/// ```
///
/// ## Style inheritance
///
/// Modifiers applied to a `Group` are inherited by every child:
///
/// ```swift
/// Group {
///     Text("A")
///     Text("B")
///     Text("C")
/// }
/// .forgroundColor(.cyan)   // all three texts become cyan
/// .render()
/// ```
public struct Group: View {
    let style: TextStyle

    /// The child views stored in this group.
    let contents: [any View]

    /// Creates a group of views using ``ViewBuilder`` syntax.
    ///
    /// - Parameter contents: A ``ViewBuilder`` closure that produces the child views.
    public init<Content: View>(@ViewBuilder contents: () -> Content) {
        self.style = .plain
        self.contents = contents()._flattenedChildren()
    }

    init(contents: [any View]) {
        self.style = .plain
        self.contents = contents
    }

    init(style: TextStyle, contents: [any View]) {
        self.style = style
        self.contents = contents
    }

    /// Returns children with the accumulated style applied.
    ///
    /// Used internally by `measure()`, `_drawChildren()`, and the flatten
    /// logic in ``HStack``/``VStack`` — avoids going through the opaque `body`.
    var _resolvedChildren: [any View] {
        style.isPlain ? contents : contents.map { $0.applyingStyle(style) }
    }

    /// `Group` is transparent: it lowers directly via ``makeNode()``.
    public var body: some View {
        EmptyView()
    }

    @_spi(RenderingInternals)
    public func applyingStyle(_ style: TextStyle) -> Self {
        return Group(style: self.style.inheriting(style), contents: self.contents)
    }

    @_spi(RenderingInternals)
    public func _flattenedChildren() -> [any View] {
        _resolvedChildren.flatMap { $0._flattenedChildren() }
    }

    /// Lowers this group into a transparent ``RenderNode/group`` node,
    /// cascading any accumulated style onto every child.
    ///
    /// The layout engine flattens group nodes into the enclosing stack, so a
    /// `Group` never introduces spacing or alignment of its own.
    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        let node = RenderNode.group(children: contents.map { $0.makeNode() })
        return style.isPlain ? node : node.applyingStyle(style)
    }
}
