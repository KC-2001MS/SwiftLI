//
//  NavigationSplitView.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/11.
//


/// A two-column container that presents a sidebar next to a detail view,
/// with ``NavigationLink``s in the sidebar driving what the detail shows.
///
/// Mirrors SwiftUI's `NavigationSplitView`, adapted to the terminal's two
/// rendering modes:
///
/// - **Full-screen** (a ``FullScreenCommand`` session): the sidebar and the
///   detail render **side by side**, separated by a vertical rule. Activating
///   a ``NavigationLink`` **replaces** the detail column with its
///   destination; the sidebar stays interactive.
/// - **Inline** (an ``InlineCommand`` session, or a one-shot render): the
///   sidebar and detail stack vertically, and activating a link **appends**
///   its destination below. Earlier layers stay visible but their controls
///   are disabled — only the newest layer counts for the session's idle
///   check.
///
/// The title bar (set with ``View/navigationTitle(_:)`` /
/// ``View/navigationSubtitle(_:)`` on the content) renders above the columns.
///
/// ```swift
/// NavigationSplitView {
///     List {
///         NavigationLink("General") { GeneralView() }
///         NavigationLink("Network") { NetworkView() }
///     }
/// } detail: {
///     Text("Select a section")
/// }
/// ```
///
/// > Note: Identity is keyed by `id` (defaults to `"NavigationSplitView"`).
/// > Give each split view a distinct `id` when a screen shows more than one.
public struct NavigationSplitView: View {
    let id: String
    let sidebar: AnyView
    let detail: AnyView

    /// Creates a split view from a sidebar and an initial detail view.
    ///
    /// - Parameters:
    ///   - id: A stable identity for the split view's navigation path.
    ///   - sidebar: A ``ViewBuilder`` producing the sidebar — typically
    ///     ``NavigationLink``s.
    ///   - detail: A ``ViewBuilder`` producing the detail shown before any
    ///     link is activated.
    public init<Sidebar: View, Detail: View>(
        id: String = "NavigationSplitView",
        @ViewBuilder sidebar: () -> Sidebar,
        @ViewBuilder detail: () -> Detail
    ) {
        self.id = id
        self.sidebar = AnyView(sidebar())
        self.detail = AnyView(detail())
    }

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

        let content: RenderNode
        if fullScreen {
            // Side by side: the sidebar stays interactive while the newest
            // destination replaces the detail column. Each column is wrapped
            // in a vstack so multiple views in its builder stack vertically —
            // a bare `.group` would be flattened into the enclosing hstack
            // and lay them out side by side.
            let sidebarNode = RenderNode.vstack(alignment: .leading, spacing: 0, children: [scoped(sidebar).makeNode()])
            let detailNode = RenderNode.vstack(alignment: .leading, spacing: 0, children: [scoped(layers.last ?? detail).makeNode()])
            let height = Swift.max(NodeLayout.measure(sidebarNode).height, NodeLayout.measure(detailNode).height)
            let rule = VStack(alignment: .leading, spacing: 0, children: (0..<height).map { _ in
                Text(content: "│").forgroundColor(.eight_bit(240))
            }).makeNode()
            content = .hstack(alignment: .top, spacing: 1, children: [sidebarNode, rule, detailNode])
        } else {
            // Inline: sidebar and detail stack vertically; destinations
            // accumulate below. Only the newest layer's controls stay live.
            var nodes: [RenderNode] = []
            if layers.isEmpty {
                nodes.append(scoped(sidebar).makeNode())
                nodes.append(scoped(detail).makeNode())
            } else {
                nodes.append(FocusCoordinator.shared.withRegistrationSuppressed { scoped(sidebar).makeNode() })
                nodes.append(FocusCoordinator.shared.withRegistrationSuppressed { scoped(detail).makeNode() })
                for (index, layer) in layers.enumerated() {
                    if index == layers.count - 1 {
                        nodes.append(scoped(layer).makeNode())
                    } else {
                        nodes.append(FocusCoordinator.shared.withRegistrationSuppressed { scoped(layer).makeNode() })
                    }
                }
            }
            content = .vstack(alignment: .leading, spacing: 0, children: nodes)
        }

        // The title bar is built *after* the content lowers — that is when
        // the active layer's `navigationTitle` registered it.
        var rows: [RenderNode] = NavigationChrome.titleBar(for: id).map { $0.makeNode() }
        rows.append(content)
        return .vstack(alignment: .leading, spacing: 0, children: rows)
    }
}
