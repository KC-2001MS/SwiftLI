//
//  Inspector.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/11.
//


public extension View {
    /// Presents an inspector pane alongside this view, mirroring SwiftUI's
    /// `inspector(isPresented:content:)`.
    ///
    /// The pane's placement follows the session's rendering mode:
    ///
    /// - **Full-screen**: the inspector renders as a trailing column beside
    ///   the view, separated by a vertical rule.
    /// - **Inline** (or a one-shot render): the inspector renders below the
    ///   view, separated by a horizontal rule.
    ///
    /// Unlike a navigation push, both the view and the inspector stay
    /// interactive while the pane is presented.
    ///
    /// ```swift
    /// @State var showsDetails = false
    ///
    /// var body: some View {
    ///     MainView()
    ///         .inspector(isPresented: $showsDetails) {
    ///             DetailsPane()
    ///         }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - isPresented: A binding that controls whether the pane is shown.
    ///   - content: A ``ViewBuilder`` producing the inspector's content.
    func inspector<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: () -> Content) -> some View {
        InspectorModifier(content: AnyView(self), isPresented: isPresented, inspector: AnyView(content()))
    }
}

/// Lays a view out beside (full-screen) or above (inline) its inspector pane
/// while the pane is presented.
struct InspectorModifier: View, @unchecked Sendable {
    let content: AnyView
    let isPresented: Binding<Bool>
    let inspector: AnyView

    public var body: some View {
        EmptyView()
    }

    @_spi(RenderingInternals)
    public func applyingStyle(_ style: TextStyle) -> Self {
        InspectorModifier(content: content.applyingStyle(style), isPresented: isPresented, inspector: inspector)
    }

    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        let base = content.makeNode()
        guard isPresented.wrappedValue else { return base }

        let pane = inspector.makeNode()
        if BodyRenderingStore.shared.fullScreenActive {
            // Trailing column, separated by a vertical rule.
            let height = Swift.max(NodeLayout.measure(base).height, NodeLayout.measure(pane).height)
            let rule = VStack(alignment: .leading, spacing: 0, children: (0..<height).map { _ in
                Text(content: "│").forgroundColor(.eight_bit(240))
            }).makeNode()
            return .hstack(alignment: .top, spacing: 1, children: [base, rule, pane])
        } else {
            // Below the content, separated by a horizontal rule.
            let rule = Text(repeating: "─", count: Swift.max(0, EnvironmentStack.current.maxWidth))
                .forgroundColor(.eight_bit(240)).makeNode()
            return .vstack(alignment: .leading, spacing: 0, children: [base, rule, pane])
        }
    }
}
