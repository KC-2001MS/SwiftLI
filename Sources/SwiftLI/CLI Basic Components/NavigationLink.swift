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
    /// An identity given explicitly, or `nil` to derive one from the label.
    let explicitID: String?
    /// The identity used when none is given — the label, made unique per
    /// position inside a session (see ``ControlIdentity``).
    let fallbackID: String
    /// The identity the control registers under.
    var id: String { ControlIdentity.resolve(explicitID, default: fallbackID) }
    let label: AnyView
    /// What activating the link pushes: a destination view built on
    /// activation, or a value the enclosing stack resolves through its
    /// `navigationDestination(for:)`. A `nil` value disables the link.
    enum Target {
        case destination(() -> AnyView)
        case value(AnyHashable?)
    }
    let target: Target

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
        let resolved = title.resolve()
        self.style = .plain
        self.explicitID = id
        self.fallbackID = resolved.isEmpty ? "NavigationLink" : resolved
        self.label = AnyView(Text(content: resolved))
        self.target = .destination { AnyView(destination()) }
    }

    /// Creates a navigation link that pushes `value` onto the enclosing
    /// stack's path, mirroring SwiftUI's `NavigationLink(_:value:)`.
    ///
    /// The stack shows the view its `navigationDestination(for:)` builds
    /// for the value's type; with a `path:` binding the value is appended to
    /// the app's own path. A `nil` value renders the link disabled.
    public init<P: Hashable>(
        _ title: LocalizedStringKey,
        value: P?,
        id: String? = nil
    ) {
        let resolved = title.resolve()
        self.style = .plain
        self.explicitID = id
        self.fallbackID = resolved.isEmpty ? "NavigationLink" : resolved
        self.label = AnyView(Text(content: resolved))
        self.target = .value(value.map { AnyHashable($0) })
    }

    /// Creates a navigation link with a custom label that pushes `value`
    /// onto the enclosing stack's path, mirroring SwiftUI's
    /// `NavigationLink(value:label:)`.
    public init<P: Hashable, Label: View>(
        value: P?,
        id: String? = nil,
        @ViewBuilder label: () -> Label
    ) {
        self.style = .plain
        self.explicitID = id
        self.fallbackID = "NavigationLink"
        self.label = AnyView(label())
        self.target = .value(value.map { AnyHashable($0) })
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
        id: String? = nil,
        @ViewBuilder destination: @escaping () -> Destination,
        @ViewBuilder label: () -> Label
    ) {
        self.style = .plain
        self.explicitID = id
        self.fallbackID = "NavigationLink"
        self.label = AnyView(label())
        self.target = .destination { AnyView(destination()) }
    }

    init(style: TextStyle, explicitID: String?, fallbackID: String, label: AnyView, target: Target) {
        self.style = style
        self.explicitID = explicitID
        self.fallbackID = fallbackID
        self.label = label
        self.target = target
    }

    /// Whether the link can push anything (a `value:` link with `nil` can't).
    private var isEnabled: Bool {
        if case .value(nil) = target { return false }
        return true
    }

    /// The link's row — `  label ›`, filled with the selection colours while
    /// focused — marked as its pointer footprint. Evaluating it also registers
    /// the link in the focus ring.
    /// `  label ›` — filled with the selection colours while focused.
    public var body: some View {
        // Focus is shown by filling the row with a background color — like a
        // selected sidebar row — rather than a marker character. The label's
        // own style attributes take precedence, so an explicit color set on
        // it still wins over the cascaded selection colors.
        if isFocused {
            row.background(.cyan).foregroundStyle(.black)
        } else {
            row
        }
    }

    private var isFocused: Bool {
        FocusCoordinator.shared.isFocused(id)
    }

    private var row: HStack {
        HStack(spacing: 0) {
            Text(content: "  ")
            label
            Text(content: " ›").foregroundStyle(isFocused ? .black : .eightBit(240))
        }
    }

    @_spi(RenderingInternals)
    public func applyingStyle(_ style: TextStyle) -> Self {
        NavigationLink(style: self.style.inheriting(style), explicitID: explicitID, fallbackID: fallbackID, label: label, target: target)
    }

    /// Registers the link in the focus ring — the enclosing container is read
    /// while lowering, inside the container's environment scope, and captured
    /// into the action — then lowers ``body`` with the link's own text style
    /// cascaded onto it as the link's pointer footprint.
    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        let container = EnvironmentStack.current.navigationContainerID
        let target = target
        if isEnabled {
            FocusCoordinator.shared.registerButton(id: id) {
                guard let container else { return }
                switch target {
                case .destination(let destination):
                    NavigationCoordinator.shared.push(destination(), onto: container)
                case .value(let value):
                    if let value { NavigationCoordinator.shared.push(value: value, onto: container) }
                }
            }
        }
        KeyInputRouter.shared.ensureStarted()
        let node = body.makeNode()
        return (style.isPlain ? node : node.applyingStyle(style)).asControl(id: id)
    }
}
