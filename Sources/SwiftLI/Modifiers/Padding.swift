//
//  Padding.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2024/05/27.
//


/// A modifier that reserves blank space around a view.
///
/// The layout engine offsets the child by the requested leading/top space and
/// reserves the requested trailing/bottom space, so padding composes cleanly
/// inside stacks.
struct PaddingModifier: ViewModifier {
    let edges: Edge.Set
    let length: Int

    func node(for content: RenderNode) -> RenderNode {
        .padding(edges: edges, length: length, child: content)
    }

    /// Horizontal padding consumes columns from the content's available width.
    func adjustEnvironment(_ values: inout EnvironmentValues) {
        var consumed = 0
        if edges.contains(.leading) { consumed += length }
        if edges.contains(.trailing) { consumed += length }
        values.maxWidth = Swift.max(0, values.maxWidth - consumed)
    }
}

// MARK: - padding modifiers on View

public extension View {

    /// Adds equal padding to all edges of this view.
    ///
    /// - Parameter length: The number of space characters to add on each edge.
    ///   Defaults to `1`.
    /// - Returns: A view with padding applied.
    func padding(_ length: Int = 1) -> some View {
        modifier(PaddingModifier(edges: .all, length: length))
    }

    /// Adds padding to the specified edges of this view.
    ///
    /// - Parameters:
    ///   - edges: The edges to pad. Use ``Edge/Set`` values such as `.leading`,
    ///     `.horizontal`, or `.all`.
    ///   - length: The number of space characters to add. Defaults to `1`.
    /// - Returns: A view with padding applied.
    func padding(_ edges: Edge.Set, _ length: Int = 1) -> some View {
        modifier(PaddingModifier(edges: edges, length: length))
    }
}
