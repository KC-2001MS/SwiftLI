//
//  TupleView.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/10.
//

/// A view created from a swift tuple of view values.
///
/// `TupleView` is what ``ViewBuilder`` produces when a builder closure contains
/// more than one view statement — it holds each child with its concrete type,
/// mirroring SwiftUI's `TupleView`. You don't create this type directly.
///
/// At render time a `TupleView` lowers to a transparent ``RenderNode/group``
/// node, so the enclosing container (or the implicit root ``VStack``) lays the
/// children out as if they had been written individually.
public struct TupleView<each Content: View>: View {
    /// The children, stored with their concrete types.
    public let value: (repeat each Content)

    /// Creates a tuple view from a tuple of views.
    public init(_ value: (repeat each Content)) {
        self.value = value
    }

    public var body: some View {
        EmptyView()
    }

    /// Cascades a style header onto every child.
    @_spi(RenderingInternals)
    public func addHeader(_ header: String) -> Self {
        TupleView((repeat (each value).addHeader(header)))
    }

    /// Lowers the children into a transparent ``RenderNode/group`` node.
    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        var children: [RenderNode] = []
        for child in repeat each value {
            children.append(child.makeNode())
        }
        return .group(children: children)
    }

    @_spi(RenderingInternals)
    public func _flattenedChildren() -> [any View] {
        var children: [any View] = []
        for child in repeat each value {
            children.append(contentsOf: child._flattenedChildren())
        }
        return children
    }
}
