//
//  NavigationStack.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/11.
//


/// A container that presents a root view and lets ``NavigationLink``s push
/// further views onto a navigation path.
///
/// Mirrors SwiftUI's `NavigationStack`, adapted to the terminal's two
/// rendering modes:
///
/// - **Inline** (an ``InlineCommand`` session, or a one-shot render): pushing
///   a destination **appends it below** the current output, the way terminal
///   output naturally flows. Earlier layers stay visible but their controls
///   are disabled — they leave the focus ring and no longer count for the
///   session's idle check, so an inline session ends when the *newest*
///   layer has nothing left to do.
/// - **Full-screen** (a ``FullScreenCommand`` session): pushing a destination
///   **replaces** the stack's content, like a page-based app.
///
/// The title bar (set with ``View/navigationTitle(_:)`` and
/// ``View/navigationSubtitle(_:)`` on the content) renders in bold above the
/// content with a rule beneath; the active layer's title wins.
///
/// ```swift
/// NavigationStack {
///     Text("Choose a section")
///     NavigationLink("Settings") {
///         SettingsView().navigationTitle("Settings")
///     }
/// }
/// ```
///
/// > Note: Identity is keyed by `id` (defaults to `"NavigationStack"`). Give
/// > each stack a distinct `id` when a screen shows more than one.
public struct NavigationStack: View {
    let id: String
    let root: AnyView

    /// Creates a navigation stack presenting `root`.
    ///
    /// - Parameters:
    ///   - id: A stable identity for the stack's navigation path.
    ///   - root: A ``ViewBuilder`` producing the stack's root content.
    public init<Content: View>(id: String = "NavigationStack", @ViewBuilder root: () -> Content) {
        self.id = id
        self.root = AnyView(root())
    }

    /// The content of the navigation stack, delegated to the rendering engine via ``makeNode()``.
    public var body: some View {
        EmptyView()
    }

    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        // Titles are re-collected from the layers this pass actually lowers.
        NavigationCoordinator.shared.clearTitles(for: id)

        let layers = NavigationCoordinator.shared.path(for: id)
        let fullScreen = BodyRenderingStore.shared.fullScreenActive

        // Scope every layer to this container so links and titles inside
        // know where they belong.
        func scoped(_ view: AnyView) -> any View {
            view.environment(\.navigationContainerID, id)
        }

        var contentNodes: [RenderNode] = []
        if fullScreen {
            // Full-screen: the newest destination replaces the content.
            let active = layers.last ?? root
            contentNodes.append(scoped(active).makeNode())
        } else {
            // Inline: destinations accumulate below the root. Only the newest
            // layer's controls stay live; the layers above it render inert.
            let all = [root] + layers
            for (index, layer) in all.enumerated() {
                if index == all.count - 1 {
                    contentNodes.append(scoped(layer).makeNode())
                } else {
                    contentNodes.append(FocusCoordinator.shared.withRegistrationSuppressed {
                        scoped(layer).makeNode()
                    })
                }
            }
        }

        // The title bar is built *after* the content lowers — that is when
        // the active layer's `navigationTitle` registered it.
        var rows: [RenderNode] = NavigationChrome.titleBar(for: id).map { $0.makeNode() }
        rows.append(contentsOf: contentNodes)
        return .vstack(alignment: .leading, spacing: 0, children: rows)
    }
}
