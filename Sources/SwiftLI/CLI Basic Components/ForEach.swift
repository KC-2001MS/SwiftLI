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
    /// The stable identity of an element, when the data is identified by an
    /// id rather than by position: a row's `@State` and lifecycle then follow
    /// the element as rows are inserted or removed around it.
    private let identity: ((Data.Element) -> AnyHashable)?
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
    /// Rows are identified by position. For data whose elements are
    /// `Identifiable`, the ``init(_:content:)`` overload constrained to
    /// `Identifiable` elements — or ``init(_:id:content:)`` — identifies
    /// rows by id instead, so a row's `@State` and `task` follow the element
    /// when the collection changes.
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
            flattenChildren: Specialised.flatten,
            identity: nil
        )
    }

    /// Creates a view that generates one child per element of `data`,
    /// identifying rows by the element's `id` — SwiftUI's
    /// `ForEach(_:content:)` for `Identifiable` data.
    ///
    /// Identity by id is what lets a row keep its `@State`, its running
    /// `task`, and its focus when rows are inserted or removed before it.
    public init(
        _ data: Data,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) where Data.Element: Identifiable {
        self.init(data, id: \.id, content: content)
    }

    /// Creates a view that generates one child per element of `data`,
    /// identifying rows by the value at `id`, mirroring SwiftUI's
    /// `ForEach(_:id:content:)`.
    ///
    /// ```swift
    /// ForEach(names, id: \.self) { name in Text(name) }
    /// ```
    public init<ID: Hashable>(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        let identity: (Data.Element) -> AnyHashable = { AnyHashable($0[keyPath: id]) }
        self.init(
            style: .plain,
            data: data,
            content: content,
            lowerChildren: { data, content in
                var children: [RenderNode] = []
                children.reserveCapacity(data.count)
                for element in data {
                    children.append(content(element).lowered(id: identity(element)))
                }
                return children
            },
            flattenChildren: Specialised.flatten,
            identity: identity
        )
    }

    @usableFromInline
    init(
        style: TextStyle,
        data: Data,
        content: @escaping (Data.Element) -> Content,
        lowerChildren: @escaping (Data, (Data.Element) -> Content) -> [RenderNode],
        flattenChildren: @escaping (Data, (Data.Element) -> Content) -> [any View],
        identity: ((Data.Element) -> AnyHashable)?
    ) {
        self.style = style
        self.data = data
        self.content = content
        self.lowerChildren = lowerChildren
        self.flattenChildren = flattenChildren
        self.identity = identity
    }

    /// `ForEach` is a structural primitive: it lowers its generated children
    /// directly and has no body.
    public typealias Body = Never

    @_spi(RenderingInternals)
    public func applyingStyle(_ style: TextStyle) -> Self {
        ForEach(style: self.style.inheriting(style), data: data, content: content, lowerChildren: lowerChildren, flattenChildren: flattenChildren, identity: identity)
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
        var views = flattenChildren(data, content)
        if let identity {
            // Flattened into a container, each row still carries its id so
            // the container lowers it under that identity.
            var identified: [any View] = []
            identified.reserveCapacity(views.count)
            var index = 0
            for element in data {
                let count = content(element).flattenedChildren().count
                let id = identity(element)
                for offset in 0..<count where index + offset < views.count {
                    identified.append(IdentifiedView(id: id, index: offset, content: views[index + offset]))
                }
                index += count
            }
            views = identified
        }
        return style.isPlain ? views : views.map { $0.styled(style) }
    }
}
