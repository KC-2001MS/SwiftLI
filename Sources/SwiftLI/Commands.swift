//
//  Commands.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/12.
//

import Foundation

// MARK: - Commands

/// Content for a command's menu bar, mirroring SwiftUI's `Commands`.
///
/// Build it with ``CommandMenu`` inside the ``Scene/commands(content:)``
/// scene modifier. Custom conformances resolve to no menus — compose the
/// built-in types instead.
public protocol Commands {}

/// A menu-bar menu in its resolved form: the title shown in the bar and the
/// item views the open menu lists.
struct ResolvedCommandMenu {
    let title: String
    let items: [any View]
}

/// The internal resolution hook the built-in ``Commands`` types implement.
protocol PrimitiveCommands {
    var resolvedCommandMenus: [ResolvedCommandMenu] { get }
}

/// Flattens any ``Commands`` into its resolved menus (empty for types the
/// library does not know).
func resolveCommandMenus(_ content: any Commands) -> [ResolvedCommandMenu] {
    (content as? PrimitiveCommands)?.resolvedCommandMenus ?? []
}

/// A top-level menu in the menu bar, mirroring SwiftUI's `CommandMenu`.
///
/// The title sits in the bar; activating it (Return / Space when focused)
/// opens the items beneath the bar. Items are ordinary views — typically
/// ``Button``s — and join the focus ring while the menu is open.
///
/// ```swift
/// .commands {
///     CommandMenu("File") {
///         Button("Open") { open() }
///         Button("Save") { save() }
///     }
/// }
/// ```
public struct CommandMenu: Commands, PrimitiveCommands {
    let title: String
    let items: [any View]

    /// Creates a menu with `title` in the bar listing `content` when open.
    public init<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = String(localized: title.localizationValue)
        self.items = content()._flattenedChildren()
    }

    var resolvedCommandMenus: [ResolvedCommandMenu] {
        [ResolvedCommandMenu(title: title, items: items)]
    }
}

/// Type-erased menu-bar content; the currency type every
/// ``CommandsBuilder`` form produces.
public struct AnyCommands: Commands, PrimitiveCommands {
    let menus: [ResolvedCommandMenu]

    /// Creates an erased copy of `content`.
    public init(_ content: any Commands) {
        self.menus = resolveCommandMenus(content)
    }

    init(menus: [ResolvedCommandMenu]) {
        self.menus = menus
    }

    var resolvedCommandMenus: [ResolvedCommandMenu] { menus }
}

// MARK: - CommandsBuilder

/// A result builder constructing menu-bar content from closures, mirroring
/// SwiftUI's `CommandsBuilder`.
///
/// Every expression is erased to ``AnyCommands``, so blocks take any number
/// of menus, and `if`, `if/else`, `switch`, and `for` all work.
@resultBuilder
public struct CommandsBuilder {
    /// Combines any number of menus into one content.
    public static func buildBlock(_ components: AnyCommands...) -> AnyCommands {
        AnyCommands(menus: components.flatMap { $0.menus })
    }

    /// A commands expression is erased so blocks stay homogeneous.
    public static func buildExpression(_ content: any Commands) -> AnyCommands {
        AnyCommands(content)
    }

    /// Produces content for an `if` statement without an `else`.
    public static func buildOptional(_ component: AnyCommands?) -> AnyCommands {
        component ?? AnyCommands(menus: [])
    }

    /// Produces content for the `true` branch of an `if`/`else`.
    public static func buildEither(first component: AnyCommands) -> AnyCommands {
        component
    }

    /// Produces content for the `false` branch of an `if`/`else`.
    public static func buildEither(second component: AnyCommands) -> AnyCommands {
        component
    }

    /// Concatenates the menus a `for` loop produces.
    public static func buildArray(_ components: [AnyCommands]) -> AnyCommands {
        AnyCommands(menus: components.flatMap { $0.menus })
    }

    /// Passes through content guarded by an `if #available` check.
    public static func buildLimitedAvailability(_ component: AnyCommands) -> AnyCommands {
        component
    }
}

// MARK: - Scene modifier

public extension Scene {
    /// Adds a menu bar above the command's content, mirroring SwiftUI's
    /// `commands(content:)` scene modifier.
    ///
    /// A command has no menu bar unless this modifier declares one. When it
    /// does, the bar takes the session's top row — above everything the
    /// content renders, including a navigation container's title bar and its
    /// toolbar — with the menu titles lined up horizontally from the leading
    /// edge. Each title is a focusable control: <kbd>Tab</kbd> reaches it,
    /// Return / Space opens the menu — its items expand *downward*, listed
    /// directly beneath the bar, and join the focus ring — and activating
    /// the title again closes it. Several `commands` modifiers accumulate
    /// their menus left to right.
    ///
    /// ```swift
    /// struct Editor: FullScreenCommand {
    ///     var body: some Scene {
    ///         DocumentView()
    ///             .commands {
    ///                 CommandMenu("File") {
    ///                     Button("Open") { open() }
    ///                     Button("Save") { save() }
    ///                 }
    ///                 CommandMenu("Help") {
    ///                     Button("About") { about() }
    ///                 }
    ///             }
    ///     }
    /// }
    /// ```
    func commands(@CommandsBuilder content: () -> some Commands) -> some Scene {
        let menus = resolveCommandMenus(content())
        return ModifiedScene(base: self) { $0.menus += menus }
    }
}

// MARK: - MenuBarCoordinator

/// Tracks which menu-bar menu is open for the current session. State lives
/// outside the view because views are rebuilt every render pass.
final class MenuBarCoordinator: @unchecked Sendable {
    static let shared = MenuBarCoordinator()

    private let lock = NSLock()
    private var _openIndex: Int? = nil

    private init() {}

    /// The index of the open menu, or `nil` when every menu is closed.
    var openIndex: Int? {
        lock.lock(); defer { lock.unlock() }
        return _openIndex
    }

    /// Opens the menu at `index`, or closes it when it is already open, and
    /// schedules a redraw.
    func toggle(_ index: Int) {
        lock.lock()
        _openIndex = _openIndex == index ? nil : index
        lock.unlock()
        StateObserverRegistry.shared.notifyChange()
    }

    /// Closes the open menu, if any, and schedules a redraw. Returns whether
    /// a menu was actually open — a click outside the menu consumes the press
    /// only when it closed something.
    func closeIfOpen() -> Bool {
        lock.lock()
        let wasOpen = _openIndex != nil
        _openIndex = nil
        lock.unlock()
        if wasOpen { StateObserverRegistry.shared.notifyChange() }
        return wasOpen
    }

    /// Closes any open menu without scheduling a redraw; called when a new
    /// session starts.
    func reset() {
        lock.lock(); _openIndex = nil; lock.unlock()
    }
}

// MARK: - MenuBarHost

/// The session chrome ``Scene/commands(content:)`` declares: the menu bar,
/// the open menu's items, a rule, then the command's content.
struct MenuBarHost: View {
    let menus: [ResolvedCommandMenu]
    let content: AnyView

    var body: some View {
        HStack(alignment: .top, spacing: 0, children: barChildren, style: .plain)
        if let open = MenuBarCoordinator.shared.openIndex, menus.indices.contains(open) {
            VStack(alignment: .leading, spacing: 0, children: menus[open].items)
                .padding(.leading, 2)
        }
        Text(repeating: "─", count: Swift.max(0, EnvironmentStack.current.maxWidth))
            .forgroundColor(.eight_bit(240))
        content
    }

    /// The bar row: one plain button per menu, the open menu's title marked.
    private var barChildren: [any View] {
        let open = MenuBarCoordinator.shared.openIndex
        var children: [any View] = []
        for (index, menu) in menus.enumerated() {
            if !children.isEmpty { children.append(Text(content: "  ")) }
            children.append(
                Button(id: "MenuBar.\(index).\(menu.title)", action: { MenuBarCoordinator.shared.toggle(index) }) {
                    if index == open {
                        Text(content: menu.title).bold().underline()
                    } else {
                        Text(content: menu.title)
                    }
                }
                .buttonStyle(.plain)
            )
        }
        return children
    }
}
