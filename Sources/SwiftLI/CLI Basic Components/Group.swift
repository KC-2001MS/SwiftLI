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
    let header: String

    /// The child views stored in this group.
    let contents: [any View]

    /// Creates a group of views using ``ViewBuilder`` syntax.
    ///
    /// - Parameter contents: A ``ViewBuilder`` closure that produces the child views.
    public init(@ViewBuilder contents: () -> Group) {
        self.header = ""
        self.contents = contents().contents
    }

    init(contents: [any View]) {
        self.header = ""
        self.contents = contents
    }

    init(header: String, contents: [any View]) {
        self.header = header
        self.contents = contents
    }

    /// Returns children with the accumulated header applied.
    ///
    /// Used internally by `measure()`, `_drawChildren()`, and the flatten
    /// logic in ``HStack``/``VStack`` — avoids going through the opaque `body`.
    var _resolvedChildren: [any View] {
        header.isEmpty ? contents : contents.map { $0.addHeader(header) }
    }

    public var body: some View {
        Group(header: "", contents: _resolvedChildren)
    }

    @_spi(RenderingInternals)
    public func addHeader(_ header: String) -> Self {
        return Group(header: header + self.header, contents: self.contents)
    }

    /// Lowers this group into a transparent ``RenderNode/group`` node,
    /// cascading any accumulated style header onto every child.
    ///
    /// The layout engine flattens group nodes into the enclosing stack, so a
    /// `Group` never introduces spacing or alignment of its own.
    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        let node = RenderNode.group(children: contents.map { $0.makeNode() })
        return header.isEmpty ? node : node.applyingHeader(header)
    }
}
