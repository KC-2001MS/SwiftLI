//
//  TabView.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/11/08.
//

import Foundation

// MARK: - Tab

/// One tab of a ``TabView``: a title, the value that selects it, and the
/// content shown while it is selected — mirroring SwiftUI's `Tab`.
///
/// ```swift
/// TabView(selection: $tab) {
///     Tab("Items", value: .items) { ItemListView() }
///     Tab("Settings", value: .settings) { SettingsView() }
/// }
/// ```
///
/// Used outside a ``TabView``, a tab simply shows its content.
public struct Tab<Value: Hashable, Content: View>: View {
    let title: String
    let value: Value?
    let content: Content
    /// The badge a `.badge(_:)` on the tab's content would set, when given
    /// here directly.
    var badge: String? = nil

    /// Creates a tab selected by `value`.
    public init(_ title: LocalizedStringKey, value: Value, @ViewBuilder content: () -> Content) {
        self.title = title.resolve()
        self.value = value
        self.content = content()
    }

    /// Creates a tab selected by `value`. The system image name is accepted
    /// for SwiftUI parity and ignored — the terminal shows the title.
    public init(_ title: LocalizedStringKey, systemImage: String, value: Value, @ViewBuilder content: () -> Content) {
        self.init(title, value: value, content: content)
    }

    init(title: String, value: Value?, content: Content, badge: String?) {
        self.title = title
        self.value = value
        self.content = content
        self.badge = badge
    }

    /// A tab is identified by its position when it has no value, so its
    /// body is its content.
    public var body: some View { content }
}

public extension Tab where Value == Never {
    /// Creates a tab selected by its position among the tabs.
    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.init(title: title.resolve(), value: nil, content: content(), badge: nil)
    }

    /// Creates a tab selected by its position. The system image name is
    /// accepted for SwiftUI parity and ignored.
    init(_ title: LocalizedStringKey, systemImage: String, @ViewBuilder content: () -> Content) {
        self.init(title: title.resolve(), value: nil, content: content(), badge: nil)
    }
}

/// How a ``TabView`` learns what a child is: a ``Tab``, or any view wearing
/// `.tabItem { }` / `.tag(_:)` / `.badge(_:)`.
protocol TabDescribing {
    var tabDescription: TabDescription { get }
}

/// The parts of one tab a ``TabView`` lays out.
struct TabDescription {
    var title: String
    var value: AnyHashable?
    var badge: String?
    var content: any View
}

extension Tab: TabDescribing {
    var tabDescription: TabDescription {
        TabDescription(title: title, value: value.map { AnyHashable($0) }, badge: badge, content: content)
    }
}

// MARK: - tabItem / tag / badge modifiers

/// Attaches a tab label to a view inside a ``TabView``; transparent
/// elsewhere. Created by ``View/tabItem(_:)``.
struct TabItemModifier: ViewModifier {
    let title: String

    func node(for content: RenderNode) -> RenderNode { content }
}

/// Attaches a selection value to a view inside a ``TabView``; transparent
/// elsewhere. Created by ``View/tag(_:)``.
struct TagModifier: ViewModifier {
    let value: AnyHashable

    func node(for content: RenderNode) -> RenderNode { content }
}

/// Attaches a badge to a view: shown in the tab bar inside a ``TabView``,
/// or trailing the view (dimmed, pushed to the far edge) elsewhere — the
/// way a `List` row shows its badge. Created by ``View/badge(_:)``.
struct BadgeModifier: ViewModifier {
    let text: String?

    func node(for content: RenderNode) -> RenderNode {
        guard let text, !text.isEmpty else { return content }
        let badge = RenderNode.text(style: TextStyle(foreground: .secondary).resolving(), contents: [text])
        return .hstack(alignment: .top, spacing: 0, children: [content, .spacer(style: .plain, minLength: 1), badge])
    }
}

public extension View {
    /// Sets the label a ``TabView`` shows for this view's tab, mirroring
    /// SwiftUI's `tabItem(_:)`. The terminal's tab bar is one text row, so
    /// the label's text is what appears — the first ``Text`` or ``Label``
    /// title in the builder.
    ///
    /// ```swift
    /// TabView(selection: $tab) {
    ///     ItemListView().tabItem { Text("Items") }.tag(Screen.items)
    ///     SettingsView().tabItem { Text("Settings") }.tag(Screen.settings)
    /// }
    /// ```
    func tabItem<Label: View>(@ViewBuilder _ label: () -> Label) -> some View {
        let plain = TextMetrics.stripANSI(label().renderString()).components(separatedBy: "\n").first ?? ""
        return modifier(TabItemModifier(title: plain.trimmingCharacters(in: .whitespaces)))
    }

    /// Sets the value that selects this view in a ``TabView``, mirroring
    /// SwiftUI's `tag(_:)`.
    func tag<V: Hashable>(_ tag: V) -> some View {
        modifier(TagModifier(value: AnyHashable(tag)))
    }

    /// Shows a count beside this view, mirroring SwiftUI's `badge(_:)`: in
    /// a ``TabView``'s tab bar next to the tab's title, elsewhere trailing
    /// the view. A zero count shows no badge.
    func badge(_ count: Int) -> some View {
        modifier(BadgeModifier(text: count == 0 ? nil : String(count)))
    }

    /// Shows a text badge beside this view, mirroring SwiftUI's `badge(_:)`.
    func badge(_ label: LocalizedStringKey?) -> some View {
        modifier(BadgeModifier(text: label?.resolve()))
    }
}

// MARK: - TabView

/// A container that switches between child views with a one-row tab bar,
/// mirroring SwiftUI's `TabView`.
///
/// The tab bar sits above the content: every tab's title in one row, the
/// selected one in bold cyan, with its badge beside it. Only the selected
/// tab's content is drawn, but every tab stays alive — its `@State`, its
/// running `task`, its scroll positions and selections — so switching back
/// shows the tab exactly as it was left, and focus returns to the control
/// that had it. Switch tabs by writing the `selection` binding, typically
/// from an ``View/onKeyPress(action:)`` handler (the terminal has no tab
/// strip to click without a pointer).
///
/// ```swift
/// enum Screen: Hashable { case items, settings }
/// @State private var screen: Screen = .items
///
/// TabView(selection: $screen) {
///     Tab("Items", value: .items) { ItemListView() }.badge(model.unread)
///     Tab("Settings", value: .settings) { SettingsView() }
/// }
/// .onKeyPress(.tab) {
///     screen = screen == .items ? .settings : .items
///     return .handled
/// }
/// ```
///
/// Children may also be plain views wearing `.tabItem { }` and `.tag(_:)`.
public struct TabView<SelectionValue: Hashable & Sendable>: View {
    let selection: Binding<SelectionValue>?
    let children: [any View]
    /// A style applied to the whole view, cascaded onto its lowered content.
    var style: TextStyle = .plain

    /// The selected tab when no binding is given.
    @State private var internalSelection: Int = 0
    /// The tab shown in the previous frame, to notice a switch.
    @State private var lastIndex: Int? = nil
    /// The control focused when each tab was last shown, by tab index.
    @State private var rememberedFocus: [Int: String] = [:]

    /// Creates a tab view whose selected tab is the one tagged with
    /// `selection`'s value.
    public init<Content: View>(selection: Binding<SelectionValue>?, @ViewBuilder content: () -> Content) {
        self.selection = selection
        self.children = content()._flattenedChildren()
    }

    /// A rendering primitive: it lowers directly via ``makeNode()`` and has
    /// no body.
    public typealias Body = Never

    @_spi(RenderingInternals)
    public func applyingStyle(_ style: TextStyle) -> Self {
        var copy = self
        copy.style = self.style.inheriting(style)
        return copy
    }

    /// The tabs, read from ``Tab`` children and from `.tabItem`/`.tag`/
    /// `.badge` modifiers on plain children.
    private var tabs: [TabDescription] {
        children.enumerated().map { index, child in
            var description = Self.describe(child) ?? TabDescription(title: "Tab \(index + 1)", value: nil, badge: nil, content: child)
            if description.title.isEmpty { description.title = "Tab \(index + 1)" }
            return description
        }
    }

    /// Peels tab metadata off a child: a ``Tab``, or a chain of
    /// `.tabItem` / `.tag` / `.badge` modifiers around any view.
    private static func describe(_ view: any View) -> TabDescription? {
        let view = view.unwrappingIdentity
        if let tab = view as? any TabDescribing { return tab.tabDescription }
        guard let modified = view as? ModifiedContent else { return nil }
        var inner = describe(modified.content) ?? TabDescription(title: "", value: nil, badge: nil, content: modified.content)
        switch modified.modifier {
        case let item as TabItemModifier:
            inner.title = item.title
        case let tag as TagModifier:
            inner.value = tag.value
        case let badge as BadgeModifier:
            inner.badge = badge.text
        default:
            // Any other modifier belongs to the content itself.
            return nil
        }
        if !modified.style.isPlain { inner.content = inner.content.styled(modified.style) }
        return inner
    }

    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        let tabs = self.tabs
        guard !tabs.isEmpty else { return .empty }

        // The selected index: the tab tagged with the binding's value, else
        // the first; without a binding, the view's own state.
        let selectedIndex: Int
        if let selection {
            let current = AnyHashable(selection.wrappedValue)
            selectedIndex = tabs.firstIndex { $0.value == current } ?? 0
        } else {
            selectedIndex = Swift.min(Swift.max(internalSelection, 0), tabs.count - 1)
        }

        // A switch rebuilds the focus ring, remembering where focus was on
        // the tab being left and restoring it on the tab being shown.
        if let last = lastIndex, last != selectedIndex {
            var remembered = rememberedFocus
            if let focused = FocusCoordinator.shared.focused { remembered[last] = focused }
            rememberedFocus = remembered
            FocusCoordinator.shared.prepareForNewLayer(refocusing: remembered[selectedIndex])
        }
        if lastIndex != selectedIndex { lastIndex = selectedIndex }

        // The tab bar: one row of titles, the selected one highlighted.
        var bar: [any View] = []
        for (index, tab) in tabs.enumerated() {
            if !bar.isEmpty { bar.append(Text(content: "  ")) }
            let selected = index == selectedIndex
            var title = Text(content: " \(tab.title) ")
            if selected {
                title = title.bold().foregroundStyle(.black).background(.cyan)
            } else {
                title = title.foregroundStyle(.secondary)
            }
            bar.append(title)
            if let badge = tab.badge, !badge.isEmpty {
                bar.append(Text(content: "(\(badge))").foregroundStyle(selected ? .yellow : .secondary))
            }
        }
        let barNode = HStack(alignment: .top, spacing: 0, children: bar, style: .plain).lowered(at: tabs.count)
        let rule = Text(repeating: "─", count: Swift.max(0, EnvironmentStack.current.maxWidth)).foregroundStyle(.eightBit(240)).lowered(at: tabs.count + 1)

        // Every tab lowers — the unselected ones inert and unseen — so each
        // keeps its state and its running work across switches. The bar and
        // its rule take two rows, so the tabs lay out in the rows that
        // remain: a `List` bounded by `\.maxHeight` then stops short of
        // pushing whatever follows the tab view off the screen.
        var contentValues = EnvironmentStack.current
        contentValues.maxHeight = Swift.max(1, contentValues.maxHeight - 2)
        var contentNode: RenderNode = .empty
        EnvironmentStack.with(contentValues) {
            for (index, tab) in tabs.enumerated() {
                if index == selectedIndex {
                    contentNode = tab.content.lowered(at: index)
                } else {
                    _ = FocusCoordinator.shared.withRegistrationSuppressed { tab.content.lowered(at: index) }
                }
            }
        }

        let node = RenderNode.vstack(alignment: .leading, spacing: 0, children: [barNode, rule, contentNode])
        return style.isPlain ? node : node.applyingStyle(style)
    }
}

public extension TabView where SelectionValue == Int {
    /// Creates a tab view that manages its own selection by tab position.
    init<Content: View>(@ViewBuilder content: () -> Content) {
        self.init(selection: nil, content: content)
    }
}

extension TabView: _StyleCarryingView {}
