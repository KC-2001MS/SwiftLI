//
//  AnyView.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/10.
//

/// A type-erased view.
///
/// Mirrors SwiftUI's `AnyView`: wraps any ``View`` value, hiding its concrete
/// type. ``ViewBuilder`` uses it for `if #available` blocks, and you can use it
/// yourself when heterogeneous view types must share one static type.
public struct AnyView: View {
    let content: any View

    /// Creates a type-erased view wrapping `view`.
    public init<V: View>(_ view: V) {
        self.content = view
    }

    /// The content and behavior of the view.
    public var body: some View {
        EmptyView()
    }

    @_spi(RenderingInternals)
    public func applyingStyle(_ style: TextStyle) -> Self {
        AnyView(erasing: content.applyingStyle(style))
    }

    init(erasing content: any View) {
        self.content = content
    }

    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        content.makeNode()
    }

    @_spi(RenderingInternals)
    public func _flattenedChildren() -> [any View] {
        content._flattenedChildren()
    }
}
