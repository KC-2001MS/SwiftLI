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
    let insets: EdgeInsets

    func node(for content: RenderNode) -> RenderNode {
        .padding(insets: insets, child: content)
    }

    /// Horizontal padding consumes columns from the content's available width.
    func adjustEnvironment(_ values: inout EnvironmentValues) {
        values.maxWidth = Swift.max(0, values.maxWidth - insets.horizontal)
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
        modifier(PaddingModifier(insets: EdgeInsets(edges: .all, length: length)))
    }

    /// Adds padding to the specified edges of this view.
    ///
    /// - Parameters:
    ///   - edges: The edges to pad. Use ``Edge/Set`` values such as `.leading`,
    ///     `.horizontal`, or `.all`.
    ///   - length: The number of space characters to add. Defaults to `1`.
    /// - Returns: A view with padding applied.
    func padding(_ edges: Edge.Set, _ length: Int = 1) -> some View {
        modifier(PaddingModifier(insets: EdgeInsets(edges: edges, length: length)))
    }

    /// Adds a different amount of padding to each edge of this view.
    ///
    /// ```swift
    /// Text("Report")
    ///     .padding(EdgeInsets(top: 1, leading: 4, bottom: 0, trailing: 2))
    /// ```
    ///
    /// - Parameter insets: The per-edge amounts of blank space to add.
    /// - Returns: A view with padding applied.
    func padding(_ insets: EdgeInsets) -> some View {
        modifier(PaddingModifier(insets: insets))
    }
}
