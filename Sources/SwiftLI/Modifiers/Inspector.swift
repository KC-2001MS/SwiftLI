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
        if isPresented.wrappedValue {
            if isFullScreen {
                // Trailing column, separated by a vertical rule that spans
                // the taller of the two (a divider stretches to its row).
                HStack(alignment: .top, spacing: 1) {
                    content
                    Divider(character: "-", verticalCharacter: "│").foregroundStyle(.eightBit(240))
                    inspector
                }
            } else {
                // Below the content, separated by a horizontal rule.
                VStack(alignment: .leading, spacing: 0) {
                    content
                    Text(repeating: "─", count: Swift.max(0, EnvironmentStack.current.maxWidth))
                        .foregroundStyle(.eightBit(240))
                    inspector
                }
            }
        } else {
            content
        }
    }

    private var isFullScreen: Bool {
        BodyRenderingStore.shared.fullScreenActive
    }

    @_spi(RenderingInternals)
    public func applyingStyle(_ style: TextStyle) -> Self {
        InspectorModifier(content: content.applyingStyle(style), isPresented: isPresented, inspector: inspector)
    }
}
