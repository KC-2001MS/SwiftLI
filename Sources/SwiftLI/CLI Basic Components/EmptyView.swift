//
//  EmptyView.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/10.
//

/// A view that renders nothing and occupies no space.
///
/// Mirrors SwiftUI's `EmptyView`. ``ViewBuilder`` produces it for an empty
/// builder block, and it is handy as an explicit "nothing" placeholder.
public struct EmptyView: View, Sendable, Equatable {
    /// Creates an empty view.
    public init() {}

    /// The content of the empty view, which renders nothing.
    public var body: some View {
        EmptyView()
    }

    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        .empty
    }

    @_spi(RenderingInternals)
    public func _flattenedChildren() -> [any View] {
        []
    }
}
