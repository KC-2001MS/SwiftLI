//
//  ViewModifier.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/09.
//


/// A transformation from a view's lowered ``RenderNode`` to another node.
///
/// Conform a value type to `ViewModifier` to describe a wrapping modifier —
/// padding, a frame, a border, and so on — purely in terms of the intermediate
/// representation: given the content's node, return the node that should take
/// its place. All of the actual behaviour (sizing, clipping, drawing) then
/// lives in ``NodeLayout``, not in a bespoke view type.
///
/// Apply a modifier with ``View/modifier(_:)``; the built-in modifiers
/// (``View/padding(_:)``, ``View/frame(width:height:alignment:)``,
/// ``View/border(_:color:fill:)``, …) are thin wrappers over it.
public protocol ViewModifier {
    /// Returns the node that replaces `content` (the modified view's node).
    func node(for content: RenderNode) -> RenderNode

    /// Adjusts the environment the modified content is lowered in.
    ///
    /// Modifiers that constrain or consume horizontal space narrow
    /// ``EnvironmentValues/maxWidth`` here so `@Environment(\.maxWidth)` reads
    /// inside the content reflect the space actually available. The default
    /// leaves the environment untouched.
    func adjustEnvironment(_ values: inout EnvironmentValues)
}

public extension ViewModifier {
    func adjustEnvironment(_ values: inout EnvironmentValues) {}
}

/// The single view that applies a ``ViewModifier`` by transforming its
/// content's lowered node. Not part of the public API — created by
/// ``View/modifier(_:)``.
struct ModifiedContent: View, @unchecked Sendable {
    let content: any View
    let modifier: any ViewModifier

    var body: some View {
        EmptyView()
    }

    func makeNode() -> RenderNode {
        var values = EnvironmentStack.current
        modifier.adjustEnvironment(&values)
        return EnvironmentStack.with(values) {
            modifier.node(for: content.makeNode())
        }
    }
}

public extension View {
    /// Applies a ``ViewModifier`` to this view, replacing its lowered node with
    /// the node the modifier produces.
    ///
    /// - Parameter modifier: The modifier to apply.
    /// - Returns: A view whose lowered node is `modifier.node(for:)` of this
    ///   view's node.
    func modifier(_ modifier: some ViewModifier) -> some View {
        ModifiedContent(content: self, modifier: modifier)
    }
}
