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

    /// Adds equal padding to all edges of this view, mirroring SwiftUI's
    /// `padding(_:)`.
    ///
    /// - Parameter length: The number of space characters to add on each edge.
    /// - Returns: A view with padding applied.
    func padding(_ length: Int) -> some View {
        modifier(PaddingModifier(insets: EdgeInsets(edges: .all, length: length)))
    }

    /// Adds padding to the specified edges of this view, mirroring SwiftUI's
    /// `padding(_:_:)`.
    ///
    /// ```swift
    /// Text("Report").padding()              // one cell on every edge
    /// Text("Report").padding(.horizontal)   // one cell left and right
    /// Text("Report").padding(.leading, 4)   // four cells on the leading edge
    /// ```
    ///
    /// - Parameters:
    ///   - edges: The edges to pad. Use ``Edge/Set`` values such as `.leading`,
    ///     `.horizontal`, or `.all`. Defaults to `.all`.
    ///   - length: The number of space characters to add, or `nil` for the
    ///     default of one cell.
    /// - Returns: A view with padding applied.
    func padding(_ edges: Edge.Set = .all, _ length: Int? = nil) -> some View {
        modifier(PaddingModifier(insets: EdgeInsets(edges: edges, length: length ?? 1)))
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
