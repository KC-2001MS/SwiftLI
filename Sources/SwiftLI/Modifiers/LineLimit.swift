//
//  LineLimit.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/07.
//


/// A modifier that caps how many visual lines a view's text renders.
struct LineLimitModifier: ViewModifier {
    let limit: Int?

    func node(for content: RenderNode) -> RenderNode {
        .lineLimit(limit, child: content)
    }
}

// MARK: - lineLimit modifier on View

public extension View {
    /// Limits the number of visual lines the view's text renders.
    ///
    /// When wrapping (inside a width-constrained frame) or explicit newlines
    /// produce more lines than `limit`, the last kept line is truncated with an
    /// ellipsis. Pass `nil` to remove any limit.
    ///
    /// - Parameter limit: The maximum number of lines, or `nil` for no limit.
    func lineLimit(_ limit: Int?) -> some View {
        modifier(LineLimitModifier(limit: limit))
    }
}
