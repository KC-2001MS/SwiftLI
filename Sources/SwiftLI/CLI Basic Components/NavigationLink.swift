//
//  NavigationLink.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/11.
//


/// A focusable control that pushes a destination view onto the enclosing
/// navigation container when activated.
///
/// `NavigationLink` mirrors SwiftUI's `NavigationLink`, adapted to the
/// terminal. While a reactive runtime is active and the link is focused,
/// <kbd>Return</kbd> or <kbd>Space</kbd> activates it, and
/// <kbd>Tab</kbd> / <kbd>Shift-Tab</kbd> move focus. It renders as its label
/// with a trailing `›` chevron; the focused link is highlighted by filling
/// the row's background, like a selected sidebar row.
///
/// What activation does depends on the session's rendering mode (see
/// ``NavigationStack``): inline sessions **append** the destination below,
/// full-screen sessions **replace** the container's content with it.
///
/// ```swift
/// NavigationStack {
///     NavigationLink("Settings") {
///         SettingsView().navigationTitle("Settings")
///     }
/// }
/// ```
///
/// Outside a ``NavigationStack`` / ``NavigationSplitView`` the link renders
/// its label but activating it does nothing.
///
/// > Note: Identity is keyed by ``id``, which defaults to the label text.
/// > Give each link a distinct label, or pass an explicit `id`, when several
/// > share the same label.
public struct NavigationLink: View {
    let style: TextStyle
    let id: String
    let label: AnyView
    let destination: () -> AnyView

    /// Creates a navigation link with a text label.
    ///
    /// - Parameters:
    ///   - title: The text shown as the link's label; also the default identity.
    ///   - id: An explicit identity; defaults to the title.
    ///   - destination: A ``ViewBuilder`` producing the view pushed on
    ///     activation. Built lazily, each time the link is activated.
    public init<Destination: View>(
        _ title: LocalizedStringKey,
        id: String? = nil,
        @ViewBuilder destination: @escaping () -> Destination
    ) {
        let resolved = String(localized: title.localizationValue)
        self.style = .plain
        self.id = id ?? (resolved.isEmpty ? "NavigationLink" : resolved)
        self.label = AnyView(Text(content: resolved))
        self.destination = { AnyView(destination()) }
    }

    /// Creates a navigation link with a custom label view.
    ///
    /// - Parameters:
    ///   - id: An explicit identity; defaults to `"NavigationLink"` — give
    ///     each link a distinct `id` when a screen shows more than one
    ///     custom-labelled link.
    ///   - destination: A ``ViewBuilder`` producing the view pushed on
    ///     activation. Built lazily, each time the link is activated.
    ///   - label: A ``ViewBuilder`` producing the link's label.
    public init<Destination: View, Label: View>(
        id: String = "NavigationLink",
        @ViewBuilder destination: @escaping () -> Destination,
        @ViewBuilder label: () -> Label
    ) {
        self.style = .plain
        self.id = id
        self.label = AnyView(label())
        self.destination = { AnyView(destination()) }
    }

    init(style: TextStyle, id: String, label: AnyView, destination: @escaping () -> AnyView) {
        self.style = style
        self.id = id
        self.label = label
        self.destination = destination
    }

    /// The content of this view; returns an empty placeholder because
    /// `NavigationLink` is rendered directly by the navigation container via
    /// ``makeNode()``.
    public var body: some View {
        EmptyView()
    }

    @_spi(RenderingInternals)
    public func applyingStyle(_ style: TextStyle) -> Self {
        NavigationLink(style: self.style.inheriting(style), id: id, label: label, destination: destination)
    }

    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        // The enclosing container is read while lowering — inside the
        // container's environment scope — and captured into the action.
        let container = EnvironmentStack.current.navigationContainerID
        let destination = destination
        FocusCoordinator.shared.registerButton(id: id) {
            guard let container else { return }
            NavigationCoordinator.shared.push(destination(), onto: container)
        }
        KeyInputRouter.shared.ensureStarted()

        let focused = FocusCoordinator.shared.isFocused(id)
        // Focus is shown by filling the row with a background color — like a
        // selected sidebar row — rather than a marker character. The label's
        // own style attributes take precedence, so an explicit color set on
        // it still wins over the cascaded selection colors.
        let row = HStack(spacing: 0) {
            Text(content: "  ")
            label
            Text(content: " ›").forgroundColor(focused ? .black : .eight_bit(240))
        }
        let styled: any View = focused ? row.background(.cyan).forgroundColor(.black) : row
        let node = styled.makeNode()
        return (style.isPlain ? node : node.applyingStyle(style)).asControl(id: id)
    }
}
