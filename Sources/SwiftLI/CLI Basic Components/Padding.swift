//
//  Padding.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2024/05/27.
//

import Foundation

/// A view that wraps another view and adds blank space around it.
///
/// Do not create `PaddingView` directly — use the `.padding()` modifier on
/// any ``View`` instead:
///
/// ```swift
/// Text("Hello, SwiftLI!")
///     .padding(.leading, 4)
///     .newLine()
///     .render()
/// // Output:     Hello, SwiftLI!
/// ```
public struct PaddingView: View, @unchecked Sendable {
    private let wrapped: any View
    private let edges: Edge.Set
    private let length: Int

    init(wrapped: any View, edges: Edge.Set, length: Int) {
        self.wrapped = wrapped
        self.edges = edges
        self.length = length
    }

    public var body: some View { Group(contents: []) }

    /// Lowers this padding view into a ``RenderNode/padding`` node wrapping the
    /// child's own lowered node.
    ///
    /// The layout engine offsets the child by the requested leading/top space
    /// and reserves the requested trailing/bottom space — no stdout capture
    /// required, which is what makes padding compose cleanly inside stacks.
    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        .padding(edges: edges, length: length, child: wrapped.makeNode())
    }
}

// MARK: - padding modifier on View

public extension View {

    /// Adds equal padding to all edges of this view.
    ///
    /// - Parameter length: The number of space characters to add on each edge.
    ///   Defaults to `1`.
    /// - Returns: A view with padding applied.
    func padding(_ length: Int = 1) -> PaddingView {
        PaddingView(wrapped: self, edges: .all, length: length)
    }

    /// Adds padding to the specified edges of this view.
    ///
    /// - Parameters:
    ///   - edges: The edges to pad. Use ``Edge/Set`` values such as `.leading`,
    ///     `.horizontal`, or `.all`.
    ///   - length: The number of space characters to add. Defaults to `1`.
    /// - Returns: A view with padding applied.
    func padding(_ edges: Edge.Set, _ length: Int = 1) -> PaddingView {
        PaddingView(wrapped: self, edges: edges, length: length)
    }
}
