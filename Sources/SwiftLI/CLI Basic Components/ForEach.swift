//
//  ForEach.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/07.
//

/// A view that produces one child view for each element of a collection.
///
/// `ForEach` mirrors SwiftUI's `ForEach`: it walks a collection and, for every
/// element, builds a view with the closure you provide. The generated views are
/// emitted as a transparent ``Group``, so a `ForEach` placed inside a
/// ``VStack`` or ``HStack`` behaves exactly as if you had written each child by
/// hand — the enclosing stack applies its own spacing and alignment.
///
/// ## Iterating over data
///
/// ```swift
/// let fruits = ["Apple", "Banana", "Cherry"]
///
/// VStack {
///     ForEach(fruits) { fruit in
///         Text("• \(fruit)")
///     }
/// }
/// .render()
/// // • Apple
/// // • Banana
/// // • Cherry
/// ```
///
/// ## Iterating over a range
///
/// Because any `RandomAccessCollection` is accepted, integer ranges work too:
///
/// ```swift
/// HStack(spacing: 1) {
///     ForEach(0..<5) { i in
///         Text("\(i)")
///     }
/// }
/// .render()
/// // 0 1 2 3 4
/// ```
///
/// ## Style inheritance
///
/// Like ``Group``, a modifier applied to the whole `ForEach` cascades to every
/// generated child:
///
/// ```swift
/// ForEach(fruits) { Text($0) }
///     .foregroundStyle(.green)   // every row becomes green
/// ```
public struct ForEach<Data: RandomAccessCollection, Content: View>: View {
    let style: TextStyle

    /// The collection whose elements drive the iteration.
    let data: Data

    /// Builds the view for a single element.
    let content: (Data.Element) -> Content

    /// Lowers every element's view, in order — see ``Specialised``.
    private let lowerChildren: (Data, (Data.Element) -> Content) -> [RenderNode]
    /// Flattens every element's view into the enclosing container's children.
    private let flattenChildren: (Data, (Data.Element) -> Content) -> [any View]

    /// The two per-element loops of a `ForEach`, built where the concrete
    /// `Data` and `Content` are known.
    ///
    /// `ForEach` is reached through `any View` at render time, so its own
    /// methods always run as unspecialised generic code: every element paid
    /// for opaque collection and view operations, which cost more than
    /// building and lowering the row itself. The public initializer is
    /// inlinable, so the closures it creates here are compiled — and
    /// specialised — in the module that declares the `ForEach`; the generic
    /// methods just call them.
    @usableFromInline
    enum Specialised {
        @inlinable
        static func lower(_ data: Data, _ content: (Data.Element) -> Content) -> [RenderNode] {
            var children: [RenderNode] = []
            children.reserveCapacity(data.count)
            var index = 0
            for element in data {
                children.append(content(element).lowered(at: index))
                index += 1
            }
            return children
        }

        @inlinable
        static func flatten(_ data: Data, _ content: (Data.Element) -> Content) -> [any View] {
            var views: [any View] = []
            views.reserveCapacity(data.count)
            for element in data {
                views.append(contentsOf: content(element).flattenedChildren())
            }
            return views
        }
    }

    /// Creates a view that generates one child per element of `data`.
    ///
    /// - Parameters:
    ///   - data: The collection to iterate over. The number of generated views
    ///     equals the number of elements.
    ///   - content: A ``ViewBuilder`` closure that produces the view for each
    ///     element.
    @inlinable
    public init(
        _ data: Data,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.init(
            style: .plain,
            data: data,
            content: content,
            lowerChildren: Specialised.lower,
            flattenChildren: Specialised.flatten
        )
    }

    @usableFromInline
    init(
        style: TextStyle,
        data: Data,
        content: @escaping (Data.Element) -> Content,
        lowerChildren: @escaping (Data, (Data.Element) -> Content) -> [RenderNode],
        flattenChildren: @escaping (Data, (Data.Element) -> Content) -> [any View]
    ) {
        self.style = style
        self.data = data
        self.content = content
        self.lowerChildren = lowerChildren
        self.flattenChildren = flattenChildren
    }

    /// `ForEach` is a structural primitive: it lowers its generated children
    /// directly and has no body.
    public typealias Body = Never

    @_spi(RenderingInternals)
    public func applyingStyle(_ style: TextStyle) -> Self {
        ForEach(style: self.style.inheriting(style), data: data, content: content, lowerChildren: lowerChildren, flattenChildren: flattenChildren)
    }

    /// Lowers the iteration into a transparent ``RenderNode/group`` node whose
    /// children are the elements' lowered views, in order.
    ///
    /// Because the result is a group, the layout engine flattens it into the
    /// enclosing stack — a `ForEach` adds no spacing or alignment of its own.
    /// Any accumulated style is cascaded onto every generated child.
    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        let node = RenderNode.group(children: lowerChildren(data, content))
        return style.isPlain ? node : node.applyingStyle(style)
    }

    /// A `ForEach` is transparent: every generated view (itself flattened)
    /// joins the enclosing container individually, with the accumulated style
    /// cascaded onto each.
    @_spi(RenderingInternals)
    public func _flattenedChildren() -> [any View] {
        let views = flattenChildren(data, content)
        return style.isPlain ? views : views.map { $0.applyingStyle(style) }
    }
}
