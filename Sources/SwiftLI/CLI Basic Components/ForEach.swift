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
///     .forgroundColor(.green)   // every row becomes green
/// ```
public struct ForEach<Data: RandomAccessCollection>: View {
    let header: String

    /// The collection whose elements drive the iteration.
    let data: Data

    /// Builds the view for a single element.
    let content: (Data.Element) -> Group

    /// Creates a view that generates one child per element of `data`.
    ///
    /// - Parameters:
    ///   - data: The collection to iterate over. The number of generated views
    ///     equals the number of elements.
    ///   - content: A ``ViewBuilder`` closure that produces the view for each
    ///     element.
    public init(
        _ data: Data,
        @ViewBuilder content: @escaping (Data.Element) -> Group
    ) {
        self.header = ""
        self.data = data
        self.content = content
    }

    init(
        header: String,
        data: Data,
        content: @escaping (Data.Element) -> Group
    ) {
        self.header = header
        self.data = data
        self.content = content
    }

    public var body: some View { Group(contents: []) }

    @_spi(RenderingInternals)
    public func addHeader(_ header: String) -> Self {
        ForEach(header: header + self.header, data: data, content: content)
    }

    /// Lowers the iteration into a transparent ``RenderNode/group`` node whose
    /// children are the elements' lowered views, in order.
    ///
    /// Because the result is a group, the layout engine flattens it into the
    /// enclosing stack — a `ForEach` adds no spacing or alignment of its own.
    /// Any accumulated style header is cascaded onto every generated child.
    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        let node = RenderNode.group(children: data.map { content($0).makeNode() })
        return header.isEmpty ? node : node.applyingHeader(header)
    }
}
