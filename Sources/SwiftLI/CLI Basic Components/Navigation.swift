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

    private let lock = NSLock()
    private var paths: [String: [AnyView]] = [:]
    private var titles: [String: String] = [:]
    private var subtitles: [String: String] = [:]
    private var barConfigs: [String: NavigationBarConfig] = [:]

    private init() {}

    /// Pushes `destination` onto `container`'s path and schedules a redraw.
    func push(_ destination: AnyView, onto container: String) {
        lock.lock()
        paths[container, default: []].append(destination)
        lock.unlock()
        // The focus ring is rebuilt from the next pass. The activated link
        // keeps focus when it is still in the new frame (a split view's
        // sidebar); only when it disappeared (a replaced stack layer) does
        // focus move to the new layer's first control.
        FocusCoordinator.shared.prepareForNewLayer()
        StateObserverRegistry.shared.notifyChange()
    }

    /// Pops the newest destination off `container`'s path (no-op when empty).
    func pop(from container: String) {
        lock.lock()
        if paths[container]?.isEmpty == false { paths[container]?.removeLast() }
        lock.unlock()
        FocusCoordinator.shared.prepareForNewLayer()
        StateObserverRegistry.shared.notifyChange()
    }

    /// The destinations pushed onto `container`, oldest first.
    func path(for container: String) -> [AnyView] {
        lock.lock(); defer { lock.unlock() }
        return paths[container] ?? []
    }

    // MARK: Title collection (content → container, within one render pass)

    /// Clears `container`'s collected titles and bar settings; called by the
    /// container at the start of its lowering so stale values never linger.
    func clearTitles(for container: String) {
        lock.lock(); defer { lock.unlock() }
        titles[container] = nil
        subtitles[container] = nil
        barConfigs[container] = nil
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
        NavigationTitleWriter(content: AnyView(self), text: String(localized: title.localizationValue), isSubtitle: false)
    }

    /// Sets the subtitle shown dimmed beneath the enclosing navigation
    /// container's title, mirroring SwiftUI's `navigationSubtitle(_:)`.
    ///
    /// Outside a navigation container the modifier has no effect.
    func navigationSubtitle(_ subtitle: LocalizedStringKey) -> some View {
        NavigationTitleWriter(content: AnyView(self), text: String(localized: subtitle.localizationValue), isSubtitle: true)
    }
}

/// Registers a title (or subtitle) with the enclosing navigation container
/// while its content lowers, then lowers the content unchanged.
struct NavigationTitleWriter: View {
    let content: AnyView
    let text: String
    let isSubtitle: Bool

    public var body: some View {
        EmptyView()
    }

    @_spi(RenderingInternals)
    public func applyingStyle(_ style: TextStyle) -> Self {
        NavigationTitleWriter(content: content.applyingStyle(style), text: text, isSubtitle: isSubtitle)
    }

    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        if let container = EnvironmentStack.current.navigationContainerID {
            if isSubtitle {
                NavigationCoordinator.shared.setSubtitle(text, for: container)
            } else {
                NavigationCoordinator.shared.setTitle(text, for: container)
            }
        }
        return content.makeNode()
    }
}

// MARK: - Shared title bar chrome

/// Builds the shared title-bar rows (bold title, dimmed subtitle, rule) for a
/// navigation container, honouring the bar settings the pass collected
/// (display mode, background, forced colour scheme, role). Empty when the
/// pass collected no title or subtitle.
enum NavigationChrome {
    static func titleBar(for container: String) -> [any View] {
        let coordinator = NavigationCoordinator.shared
        let title = coordinator.title(for: container)
        let subtitle = coordinator.subtitle(for: container)
        let config = coordinator.barConfig(for: container)
        guard title != nil || subtitle != nil || !config.toolbarItems.isEmpty else { return [] }

        // .editor centres the title the way an editor window names its
        // document; the other roles keep it leading.
        let centered = config.role == .editor

        // A forced bar colour scheme picks the text colours; otherwise the
        // regular title colours apply.
        let titleColor: Color? = config.colorScheme.map { $0 == .dark ? .white : .black }
        let subtitleColor: Color = config.colorScheme.map { $0 == .dark ? .eight_bit(250) : .eight_bit(240) } ?? .secondary

        func titleText(_ text: String) -> AnyView {
            let base = Text(content: text).bold()
            if let titleColor { return AnyView(base.forgroundColor(titleColor)) }
            return AnyView(base)
        }

        func subtitleText(_ text: String) -> AnyView {
            AnyView(Text(content: text).forgroundColor(subtitleColor))
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
            .forgroundColor(.eight_bit(240))
        if let background = config.background {
            rows.append(rule.background(background))
        } else {
            rows.append(rule)
        }
        return rows
    }
}
