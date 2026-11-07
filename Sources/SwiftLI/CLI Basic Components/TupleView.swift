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

    /// A style applied to the whole tuple, cascaded onto every child when
    /// the tuple lowers (so composite children receive it too).
    var style: TextStyle = .plain

    /// Creates a tuple view from a tuple of views.
    public init(_ value: (repeat each Content)) {
        self.value = value
    }

    /// `TupleView` is a structural primitive: its parent container lowers its
    /// children directly, so it has no body.
    public typealias Body = Never

    /// Cascades a style onto every child.
    @_spi(RenderingInternals)
    public func applyingStyle(_ style: TextStyle) -> Self {
        var copy = self
        copy.style = self.style.inheriting(style)
        return copy
    }

    /// Lowers the children into a transparent ``RenderNode/group`` node.
    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        var children: [RenderNode] = []
        for child in repeat each value {
            children.append(child.lowered(at: children.count))
        }
        let node = RenderNode.group(children: children)
        return style.isPlain ? node : node.applyingStyle(style)
    }

    /// Each tuple slot's flattened children are keyed by the slot, so a slot
    /// whose child count changes (an `if` that turns false, a `ForEach` that
    /// grows) never shifts the identity of the slots after it.
    @_spi(RenderingInternals)
    public func _flattenedChildren() -> [any View] {
        var children: [any View] = []
        var slot = 0
        for child in repeat each value {
            for (index, flattened) in child._flattenedChildren().enumerated() {
                children.append(IdentifiedView(id: AnyHashable(slot), index: index, content: flattened))
            }
            slot += 1
        }
        return style.isPlain ? children : children.map { $0.styled(style) }
    }
}
