//
//  Navigation.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/11.
//

import Foundation

// MARK: - NavigationBarConfig

/// The title-bar settings collected from content during one render pass:
/// display mode, background fill, forced colour scheme, and role.
///
/// Declared by the `toolbar*` / `navigationBarTitleDisplayMode` modifiers and
/// read back by ``NavigationChrome`` when the container builds its title bar.
struct NavigationBarConfig {
    var titleDisplayMode: NavigationBarItem.TitleDisplayMode = .automatic
    var background: Color? = nil
    var colorScheme: ColorScheme? = nil
    var role: ToolbarRole = .automatic
    var toolbarItems: [ResolvedToolbarItem] = []
}

// MARK: - NavigationCoordinator

/// Tracks the pushed destinations and collected titles of every navigation
/// container (``NavigationStack`` / ``NavigationSplitView``), keyed by
/// container id.
///
/// ``NavigationLink`` pushes destinations here; the containers read the path
/// back while lowering. Titles work like a preference: the *content* declares
/// them (``View/navigationTitle(_:)``) while it is lowered, and the container
/// — which lowers its content first — renders them above it afterwards.
final class NavigationCoordinator: @unchecked Sendable {

    /// The process-wide coordinator used by the navigation views.
    static let shared = NavigationCoordinator()

    /// One pushed layer of a container's path: a view built by a
    /// ``NavigationLink`` destination closure, or a value a
    /// `navigationDestination(for:)` resolves when the container lowers.
    enum Layer {
        case view(AnyView)
        case value(AnyHashable)
    }

    /// The hooks a ``NavigationStack`` created with a `path:` binding
    /// registers, so pushes and pops go through the app's own array.
    struct PathBinding {
        let count: () -> Int
        let append: (AnyHashable) -> Bool
        let removeLast: () -> Void
    }

    private let lock = NSLock()
    private var paths: [String: [Layer]] = [:]
    private var titles: [String: String] = [:]
    private var subtitles: [String: String] = [:]
    private var barConfigs: [String: NavigationBarConfig] = [:]
    /// The typed path bindings of the stacks created with `path:`.
    private var pathBindings: [String: PathBinding] = [:]
    /// The `navigationDestination(for:)` builders collected while each
    /// container's content lowered, keyed by the data type's identity.
    private var destinations: [String: [ObjectIdentifier: (AnyHashable) -> AnyView]] = [:]
    /// The number of layers each container showed in its last frame, so a
    /// path that changed programmatically (an `append` from a key handler)
    /// rebuilds the focus ring exactly as a link activation does.
    private var observedCounts: [String: Int] = [:]
    /// The rows each container's title bar and bottom bar took in its last
    /// frame, reserved out of `\.maxHeight` when its content lowers.
    private var chromeHeights: [String: Int] = [:]

    private init() {}

    /// The rows `container`'s bars took in its last frame (0 before the
    /// first).
    func chromeHeight(for container: String) -> Int {
        lock.lock(); defer { lock.unlock() }
        return chromeHeights[container] ?? 0
    }

    /// Records the rows `container`'s bars take this frame; `true` when that
    /// differs from what its content was laid out against.
    func recordChromeHeight(_ height: Int, for container: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        let previous = chromeHeights[container] ?? 0
        chromeHeights[container] = height
        return previous != height
    }

    /// Pushes `destination` onto `container`'s path and schedules a redraw.
    func push(_ destination: AnyView, onto container: String) {
        lock.lock()
        paths[container, default: []].append(.view(destination))
        observedCounts[container] = (observedCounts[container] ?? 0) + 1
        lock.unlock()
        // The focus ring is rebuilt from the next pass. The activated link
        // keeps focus when it is still in the new frame (a split view's
        // sidebar); only when it disappeared (a replaced stack layer) does
        // focus move to the new layer's first control.
        FocusCoordinator.shared.prepareForNewLayer()
        StateObserverRegistry.shared.notifyChange()
    }

    /// Pushes `value` onto `container`'s path — through the stack's `path:`
    /// binding when it has one, otherwise onto the internal path — and
    /// schedules a redraw. The value is resolved to a view by the matching
    /// `navigationDestination(for:)` when the container next lowers.
    func push(value: AnyHashable, onto container: String) {
        lock.lock()
        let binding = pathBindings[container]
        if binding == nil {
            paths[container, default: []].append(.value(value))
            observedCounts[container] = (observedCounts[container] ?? 0) + 1
        }
        lock.unlock()
        if let binding {
            // The binding's own state write schedules the redraw; the
            // container notices the new count when it lowers.
            _ = binding.append(value)
            return
        }
        FocusCoordinator.shared.prepareForNewLayer()
        StateObserverRegistry.shared.notifyChange()
    }

    /// Pops the newest destination off `container`'s path (no-op when empty).
    func pop(from container: String) {
        lock.lock()
        let binding = pathBindings[container]
        if binding == nil, paths[container]?.isEmpty == false {
            paths[container]?.removeLast()
            observedCounts[container] = Swift.max(0, (observedCounts[container] ?? 1) - 1)
        }
        lock.unlock()
        if let binding {
            if binding.count() > 0 { binding.removeLast() }
            return
        }
        FocusCoordinator.shared.prepareForNewLayer()
        StateObserverRegistry.shared.notifyChange()
    }

    /// The destinations pushed onto `container`, oldest first, resolved to
    /// views (a value without a matching destination shows a placeholder).
    func path(for container: String) -> [AnyView] {
        layers(for: container).map { resolve($0, in: container) }
    }

    /// The layers of `container`'s path: the typed binding's values when the
    /// stack has one, else the internal path.
    func layers(for container: String) -> [Layer] {
        lock.lock(); defer { lock.unlock() }
        return paths[container] ?? []
    }

    /// Resolves a layer to the view it shows.
    func resolve(_ layer: Layer, in container: String) -> AnyView {
        switch layer {
        case .view(let view):
            return view
        case .value(let value):
            lock.lock()
            let builder = destinations[container]?[ObjectIdentifier(type(of: value.base))]
            lock.unlock()
            if let builder { return builder(value) }
            return AnyView(Text(content: "No navigationDestination(for: \(type(of: value.base)).self)").foregroundStyle(.red))
        }
    }

    /// Registers the `path:` binding of a stack for this pass (every pass,
    /// so the coordinator always holds the latest binding).
    func registerPathBinding(_ binding: PathBinding?, for container: String) {
        lock.lock(); defer { lock.unlock() }
        pathBindings[container] = binding
    }

    /// Registers a `navigationDestination(for:)` builder declared inside
    /// `container`'s content, for the data type `type`.
    func registerDestination(for container: String, type: Any.Type, builder: @escaping (AnyHashable) -> AnyView) {
        lock.lock(); defer { lock.unlock() }
        destinations[container, default: [:]][ObjectIdentifier(type)] = builder
    }

    /// Records the layer count `container` shows this frame and reports
    /// whether it differs from the previous frame — a programmatic path
    /// change that must rebuild the focus ring.
    func observeLayerCount(_ count: Int, for container: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        let previous = observedCounts[container]
        observedCounts[container] = count
        guard let previous else { return false }
        return previous != count
    }

    // MARK: Title collection (content → container, within one render pass)

    /// Clears `container`'s collected titles and bar settings; called by the
    /// container at the start of its lowering so stale values never linger.
    func clearTitles(for container: String) {
        lock.lock(); defer { lock.unlock() }
        titles[container] = nil
        subtitles[container] = nil
        barConfigs[container] = nil
        destinations[container] = nil
    }

    /// Records the title declared by content inside `container`. The layer
    /// lowered last (the active one) wins.
    func setTitle(_ title: String, for container: String) {
        lock.lock(); defer { lock.unlock() }
        titles[container] = title
    }

    /// Records the subtitle declared by content inside `container`.
    func setSubtitle(_ subtitle: String, for container: String) {
        lock.lock(); defer { lock.unlock() }
        subtitles[container] = subtitle
    }

    /// Applies one title-bar setting declared by content inside `container`,
    /// on top of whatever this pass collected so far. The layer lowered last
    /// (the active one) wins, like titles.
    func updateBarConfig(for container: String, _ update: (inout NavigationBarConfig) -> Void) {
        lock.lock(); defer { lock.unlock() }
        var config = barConfigs[container] ?? NavigationBarConfig()
        update(&config)
        barConfigs[container] = config
    }

    /// The title collected during this pass, if any.
    func title(for container: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        return titles[container]
    }

    /// The subtitle collected during this pass, if any.
    func subtitle(for container: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        return subtitles[container]
    }

    /// The title-bar settings collected during this pass (defaults when the
    /// content declared none).
    func barConfig(for container: String) -> NavigationBarConfig {
        lock.lock(); defer { lock.unlock() }
        return barConfigs[container] ?? NavigationBarConfig()
    }

    /// Clears all navigation state (paths and titles).
    func reset() {
        lock.lock(); defer { lock.unlock() }
        paths.removeAll()
        titles.removeAll()
        subtitles.removeAll()
        barConfigs.removeAll()
        pathBindings.removeAll()
        destinations.removeAll()
        observedCounts.removeAll()
        chromeHeights.removeAll()
    }
}

// MARK: - navigationDestination

/// The modifier behind ``View/navigationDestination(for:destination:)``:
/// registers the destination builder with the enclosing container while the
/// content lowers.
struct NavigationDestinationModifier<D: Hashable>: ViewModifier {
    let destination: (D) -> AnyView

    func node(for content: RenderNode) -> RenderNode {
        content
    }

    func node(lowering content: () -> RenderNode) -> RenderNode {
        if let container = EnvironmentStack.current.navigationContainerID {
            let destination = destination
            NavigationCoordinator.shared.registerDestination(for: container, type: D.self) { value in
                guard let typed = value.base as? D else { return AnyView(EmptyView()) }
                return destination(typed)
            }
        }
        return content()
    }
}

public extension View {
    /// Associates a destination view with a data type presented by the
    /// enclosing ``NavigationStack``, mirroring SwiftUI's
    /// `navigationDestination(for:destination:)`.
    ///
    /// When a value of `data`'s type is pushed — by a ``NavigationLink``
    /// created with `value:`, or by appending to the stack's `path:` binding
    /// — the stack shows the view `destination` builds for it.
    ///
    /// ```swift
    /// NavigationStack(path: $path) {
    ///     List(items, selection: $selection) { ItemRow(item: $0) }
    ///         .onSubmit { if let id = selection { path.append(Route.detail(id)) } }
    ///         .navigationDestination(for: Route.self) { route in
    ///             switch route {
    ///             case .detail(let id): DetailView(id: id)
    ///             case .settings: SettingsView()
    ///             }
    ///         }
    /// }
    /// ```
    func navigationDestination<D: Hashable, Content: View>(
        for data: D.Type,
        @ViewBuilder destination: @escaping (D) -> Content
    ) -> some View {
        modifier(NavigationDestinationModifier<D>(destination: { AnyView(destination($0)) }))
    }
}

// MARK: - Environment

private struct NavigationContainerIDKey: EnvironmentKey {
    static var defaultValue: String? { nil }
}

extension EnvironmentValues {
    /// The id of the innermost enclosing navigation container, or `nil`
    /// outside of one. Set by ``NavigationStack``/``NavigationSplitView`` so
    /// ``NavigationLink`` knows where to push and
    /// ``View/navigationTitle(_:)`` knows whose title bar to fill.
    var navigationContainerID: String? {
        get { self[NavigationContainerIDKey.self] }
        set { self[NavigationContainerIDKey.self] = newValue }
    }
}

// MARK: - Title modifiers

public extension View {
    /// Sets the title shown in the enclosing navigation container's title
    /// bar, mirroring SwiftUI's `navigationTitle(_:)`.
    ///
    /// The container renders the title in bold above its content, with a rule
    /// beneath. When several layers set a title, the active (newest) layer
    /// wins. Outside a navigation container the modifier has no effect.
    ///
    /// ```swift
    /// NavigationStack {
    ///     Text("...").navigationTitle("Settings")
    /// }
    /// ```
    func navigationTitle(_ title: LocalizedStringKey) -> some View {
        modifier(NavigationTitleModifier(text: title.resolve(), isSubtitle: false))
    }

    /// Sets the title shown in the enclosing navigation container's title
    /// bar from a string value, mirroring SwiftUI's `navigationTitle(_:)`
    /// for `StringProtocol`.
    func navigationTitle<S: StringProtocol>(_ title: S) -> some View {
        modifier(NavigationTitleModifier(text: String(title), isSubtitle: false))
    }

    /// Sets the subtitle shown dimmed beneath the enclosing navigation
    /// container's title, mirroring SwiftUI's `navigationSubtitle(_:)`.
    ///
    /// Outside a navigation container the modifier has no effect.
    func navigationSubtitle(_ subtitle: LocalizedStringKey) -> some View {
        modifier(NavigationTitleModifier(text: subtitle.resolve(), isSubtitle: true))
    }
}

/// Registers a title (or subtitle) with the enclosing navigation container
/// while its content lowers, then lowers the content unchanged.
struct NavigationTitleModifier: ViewModifier {
    let text: String
    let isSubtitle: Bool

    func node(for content: RenderNode) -> RenderNode {
        content
    }

    func node(lowering content: () -> RenderNode) -> RenderNode {
        if let container = EnvironmentStack.current.navigationContainerID {
            if isSubtitle {
                NavigationCoordinator.shared.setSubtitle(text, for: container)
            } else {
                NavigationCoordinator.shared.setTitle(text, for: container)
            }
        }
        return content()
    }
}

// MARK: - Shared title bar chrome

/// Builds the shared title-bar rows (bold title, dimmed subtitle, rule) for a
/// navigation container, honouring the bar settings the pass collected
/// (display mode, background, forced colour scheme, role). Empty when the
/// pass collected no title or subtitle.
enum NavigationChrome {
    /// The bottom bar rows: a flexible spacer that pushes the bar to the
    /// last row of the available height, then the `.bottomBar` toolbar items
    /// in one row. Empty when no item has that placement.
    static func bottomBar(for container: String) -> [any View] {
        let config = NavigationCoordinator.shared.barConfig(for: container)
        let items = config.toolbarItems.filter { $0.placement.segment == .bottom }
        guard !items.isEmpty else { return [] }
        var row: [any View] = []
        for item in items {
            if !row.isEmpty { row.append(Text(content: "  ")) }
            row.append(item.view.labelStyle(.iconOnly).buttonStyle(.plain))
        }
        let bar = HStack(alignment: .top, spacing: 0, children: row, style: .plain)
        let styled: any View = config.background.map { AnyView(HStack(spacing: 0) { bar; Spacer() }.background($0)) } ?? AnyView(bar)
        return [Spacer(minLength: 0), styled]
    }

    static func titleBar(for container: String) -> [any View] {
        let coordinator = NavigationCoordinator.shared
        let title = coordinator.title(for: container)
        let subtitle = coordinator.subtitle(for: container)
        let config = coordinator.barConfig(for: container)
        guard title != nil || subtitle != nil || config.toolbarItems.contains(where: { $0.placement.segment != .bottom }) else { return [] }

        // .editor centres the title the way an editor window names its
        // document; the other roles keep it leading.
        let centered = config.role == .editor

        // A forced bar colour scheme picks the text colours; otherwise the
        // regular title colours apply.
        let titleColor: Color? = config.colorScheme.map { $0 == .dark ? .white : .black }
        let subtitleColor: Color = config.colorScheme.map { $0 == .dark ? .eightBit(250) : .eightBit(240) } ?? .secondary

        func titleText(_ text: String) -> AnyView {
            let base = Text(content: text).bold()
            if let titleColor { return AnyView(base.foregroundStyle(titleColor)) }
            return AnyView(base)
        }

        func subtitleText(_ text: String) -> AnyView {
            AnyView(Text(content: text).foregroundStyle(subtitleColor))
        }

        // Toolbar items render icon-only labels and plain (label-only)
        // buttons; Text passes through unchanged. A style set directly on a
        // control still overrides these subtree defaults.
        func itemView(_ item: ResolvedToolbarItem) -> any View {
            item.view.labelStyle(.iconOnly).buttonStyle(.plain)
        }
        let leadingItems = config.toolbarItems.filter { $0.placement.segment == .leading }.map(itemView)
        let centerItems = config.toolbarItems.filter { $0.placement.segment == .center }.map(itemView)
        let trailingItems = config.toolbarItems.filter { $0.placement.segment == .trailing }.map(itemView)

        // Joins row pieces with real space cells — not stack spacing — so a
        // bar background reaches every column.
        func joined(_ views: [any View]) -> [any View] {
            var out: [any View] = []
            for view in views {
                if !out.isEmpty { out.append(Text(content: " ")) }
                out.append(view)
            }
            return out
        }

        // The title cluster: the bold title, plus the subtitle when the
        // inline display mode folds it into the same row.
        var cluster: [any View] = []
        if let title { cluster.append(titleText(title)) }
        let inlineSubtitle = config.titleDisplayMode == .inline && subtitle != nil
        if inlineSubtitle, let subtitle {
            if !cluster.isEmpty { cluster.append(Text(content: "  ")) }
            cluster.append(subtitleText(subtitle))
        }

        // Pads a bar row with spacers — not frames — so a background reaches
        // every column (backgrounds attach per glyph cell, and Spacer's fill
        // carries them; a frame's padding cells would stay uncoloured).
        func barRow(_ content: AnyView) -> any View {
            guard config.background != nil || centered else { return content }
            let padded = centered
                ? AnyView(HStack(spacing: 0) { Spacer(); content; Spacer() })
                : AnyView(HStack(spacing: 0) { content; Spacer() })
            if let background = config.background { return padded.background(background) }
            return padded
        }

        var rows: [any View] = []

        // Title row: leading items then the title cluster (the .editor role
        // moves the cluster to the centre segment), centre items mid-bar,
        // trailing items at the right edge.
        let left = joined(centered ? leadingItems : leadingItems + cluster)
        let center = joined(centered ? cluster + centerItems : centerItems)
        let right = joined(trailingItems)

        let needsFullRow = config.background != nil || !center.isEmpty || !right.isEmpty
        if !needsFullRow {
            if !left.isEmpty {
                rows.append(HStack(alignment: .top, spacing: 0, children: left, style: .plain))
            }
        } else {
            var parts: [any View] = left
            if !center.isEmpty {
                parts.append(Spacer(minLength: 1))
                parts.append(contentsOf: center)
            }
            parts.append(Spacer(minLength: 1))
            parts.append(contentsOf: right)
            let row = HStack(alignment: .top, spacing: 0, children: parts, style: .plain)
            if let background = config.background {
                rows.append(row.background(background))
            } else {
                rows.append(row)
            }
        }

        // Subtitle row, unless the inline display mode already folded it
        // into the title row.
        if !inlineSubtitle, let subtitle {
            rows.append(barRow(subtitleText(subtitle)))
        }

        // The same light rule Table draws under its header, at full width.
        let rule = Text(repeating: "─", count: Swift.max(0, EnvironmentStack.current.maxWidth))
            .foregroundStyle(.eightBit(240))
        if let background = config.background {
            rows.append(rule.background(background))
        } else {
            rows.append(rule)
        }
        return rows
    }
}
