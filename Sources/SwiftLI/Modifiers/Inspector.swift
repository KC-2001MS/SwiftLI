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
        modifier(InspectorModifier(isPresented: isPresented, inspector: AnyView(content())))
    }
}

/// Lays a view out beside (full-screen) or above (inline) its inspector pane
/// while the pane is presented.
struct InspectorModifier: ViewModifier {
    let isPresented: Binding<Bool>
    let inspector: AnyView

    func node(for content: RenderNode) -> RenderNode {
        content
    }

    func node(lowering content: () -> RenderNode) -> RenderNode {
        guard isPresented.wrappedValue else { return content() }
        let ruleColor = Color.eightBit(240)
        if BodyRenderingStore.shared.fullScreenActive {
            // Trailing column, separated by a vertical rule that spans the
            // taller of the two (a divider stretches to its row).
            let rule = Divider(character: "-", verticalCharacter: "│").foregroundStyle(ruleColor)
            return .hstack(alignment: .top, spacing: 1, children: [
                content(),
                rule.makeNode(),
                inspector.lowered(at: 2),
            ])
        } else {
            // Below the content, separated by a horizontal rule.
            let rule = Text(repeating: "─", count: Swift.max(0, EnvironmentStack.current.maxWidth))
                .foregroundStyle(ruleColor)
            return .vstack(alignment: .leading, spacing: 0, children: [
                content(),
                rule.makeNode(),
                inspector.lowered(at: 2),
            ])
        }
    }
}
