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
/// Inside a pushed destination, `@Environment(\.dismiss)` pops that
/// destination off the stack (as it does in SwiftUI) instead of ending the
/// session — pair it with ``View/onKeyPress(_:action:)`` for a "back" key:
///
/// ```swift
/// struct DetailView: View {
///     @Environment(\.dismiss) private var dismiss
///     var body: some View {
///         Text("Detail")
///             .onKeyPress(.escape) { dismiss(); return .handled }
///     }
/// }
/// ```
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
    /// The app-owned path when the stack was created with `path:`, erased so
    /// the coordinator can push and pop through it.
    let pathBinding: NavigationCoordinator.PathBinding?
    /// A style applied to the whole stack, cascaded onto its lowered content.
    var style: TextStyle = .plain

    /// Creates a navigation stack presenting `root`.
    ///
    /// - Parameters:
    ///   - id: A stable identity for the stack's navigation path.
    ///   - root: A ``ViewBuilder`` producing the stack's root content.
    public init<Content: View>(id: String = "NavigationStack", @ViewBuilder root: () -> Content) {
        self.id = id
        self.root = AnyView(root())
        self.pathBinding = nil
    }

    /// Creates a navigation stack whose pushed destinations are the values
    /// of `path`, mirroring SwiftUI's `NavigationStack(path:root:)`.
    ///
    /// Each value is shown by the `navigationDestination(for:)` declared
    /// inside the stack for its type. Append to the path to push, remove
    /// from it to pop; a ``NavigationLink`` created with `value:` appends,
    /// and `@Environment(\.dismiss)` inside a destination removes the last
    /// element.
    ///
    /// ```swift
    /// @State private var path: [Route] = []
    ///
    /// NavigationStack(path: $path) {
    ///     ItemList()
    ///         .navigationDestination(for: Route.self) { route in RouteView(route) }
    /// }
    /// .onKeyPress(.escape) { path.removeLast(); return .handled }
    /// ```
    public init<Data: Hashable, Content: View>(path: Binding<[Data]>, id: String = "NavigationStack", @ViewBuilder root: () -> Content) {
        self.id = id
        self.root = AnyView(root())
        self.pathBinding = NavigationCoordinator.PathBinding(
            count: { path.wrappedValue.count },
            append: { value in
                guard let typed = value.base as? Data else { return false }
                path.wrappedValue.append(typed)
                return true
            },
            removeLast: {
                guard !path.wrappedValue.isEmpty else { return }
                path.wrappedValue.removeLast()
            }
        )
        self.typedLayers = { path.wrappedValue.map { NavigationCoordinator.Layer.value(AnyHashable($0)) } }
    }

    /// The layers of a typed path, read each pass; `nil` for a stack with an
    /// internal path.
    private var typedLayers: (() -> [NavigationCoordinator.Layer])? = nil

    @_spi(RenderingInternals)
    public func applyingStyle(_ style: TextStyle) -> Self {
        var copy = self
        copy.style = self.style.inheriting(style)
        return copy
    }

    /// The title bar above the stack's layers: the active layer alone in
    /// full-screen mode, every layer (older ones inert) inline.
    /// A navigation container is a rendering root: it lowers its layers
    /// directly (older ones with registration suppressed) and has no body.
    public typealias Body = Never

    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        let coordinator = NavigationCoordinator.shared
        // Titles and destinations are re-collected from the layers this pass
        // actually lowers.
        coordinator.clearTitles(for: id)
        coordinator.registerPathBinding(pathBinding, for: id)

        let layers = typedLayers?() ?? coordinator.layers(for: id)
        let fullScreen = BodyRenderingStore.shared.fullScreenActive

        // A path that changed since the last frame without going through a
        // link (an `append` in a key handler, a `removeLast` from `dismiss`)
        // rebuilds the focus ring exactly as a link activation does.
        if coordinator.observeLayerCount(layers.count, for: id) {
            FocusCoordinator.shared.prepareForNewLayer()
        }

        // Scope every layer to this container so links and titles inside
        // know where they belong. A pushed layer also gets a `\.dismiss` that
        // pops it, so a destination can navigate back the SwiftUI way.
        func scoped(_ view: AnyView, pushed: Bool) -> any View {
            let scopedView = AnyView(view.environment(\.navigationContainerID, id))
            guard pushed else { return scopedView }
            let id = id
            return scopedView.environment(\.dismiss, DismissAction {
                NavigationCoordinator.shared.pop(from: id)
            })
        }

        /// Lowers layer `index` (0 is the root) under an identity that
        /// follows the pushed value, so a destination's `@State` belongs to
        /// what it shows.
        func lower(_ view: any View, layerIndex index: Int, layer: NavigationCoordinator.Layer?) -> RenderNode {
            if case .value(let value)? = layer {
                return view.lowered(id: AnyHashable([AnyHashable(index), value]))
            }
            return view.lowered(at: index)
        }

        // The title bar and bottom bar take rows the content cannot have, so
        // the layers lay out in `\.maxHeight` less those rows — a `List`
        // bounded by it then leaves the bars (and anything below the stack)
        // on screen. How many rows the bars take is only known once the
        // content has lowered (that is when the active layer's
        // `navigationTitle` registers), so the reservation is the previous
        // frame's; when this frame's bars differ, a follow-up frame is
        // queued and lays the content out against the right number.
        let reservedRows = coordinator.chromeHeight(for: id)
        var contentValues = EnvironmentStack.current
        contentValues.maxHeight = Swift.max(1, contentValues.maxHeight - reservedRows)

        var contentNodes: [RenderNode] = []
        EnvironmentStack.with(contentValues) {
            // The root always lowers — inert and discarded when a destination
            // covers it in full-screen mode — so it stays alive beneath the
            // stack as in SwiftUI: its `@State` persists, its `task` keeps
            // running, and the `navigationDestination(for:)` modifiers it
            // declares are registered before the pushed values resolve.
            if layers.isEmpty {
                contentNodes.append(lower(scoped(root, pushed: false), layerIndex: 0, layer: nil))
            } else {
                let rootNode = FocusCoordinator.shared.withRegistrationSuppressed {
                    lower(scoped(root, pushed: false), layerIndex: 0, layer: nil)
                }
                if !fullScreen { contentNodes.append(rootNode) }
                for (offset, layer) in layers.enumerated() {
                    let index = offset + 1
                    let view = scoped(coordinator.resolve(layer, in: id), pushed: true)
                    if offset == layers.count - 1 {
                        contentNodes.append(lower(view, layerIndex: index, layer: layer))
                    } else {
                        // Older layers render inert inline, and stay alive but
                        // unseen in full-screen mode.
                        let node = FocusCoordinator.shared.withRegistrationSuppressed {
                            lower(view, layerIndex: index, layer: layer)
                        }
                        if !fullScreen { contentNodes.append(node) }
                    }
                }
            }
        }

        // The title bar is built *after* the content lowers — that is when
        // the active layer's `navigationTitle` registered it.
        let titleRows = NavigationChrome.titleBar(for: id).map { $0.makeNode() }
        let bottomRows = NavigationChrome.bottomBar(for: id).map { $0.makeNode() }
        let proposedWidth = EnvironmentStack.current.maxWidth
        var chromeRows = titleRows.reduce(0) { $0 + NodeLayout.measure($1, proposedWidth: proposedWidth).height }
        // The bottom bar's leading spacer only pushes it down; the bar row
        // itself is what takes space.
        if let bar = bottomRows.last {
            chromeRows += NodeLayout.measure(bar, proposedWidth: proposedWidth).height
        }
        if coordinator.recordChromeHeight(chromeRows, for: id) {
            StateObserverRegistry.shared.notifyChange()
        }

        var rows = titleRows
        rows.append(contentsOf: contentNodes)
        rows.append(contentsOf: bottomRows)
        let node = RenderNode.vstack(alignment: .leading, spacing: 0, children: rows)
        return style.isPlain ? node : node.applyingStyle(style)
    }
}

extension NavigationStack: _StyleCarryingView {}
