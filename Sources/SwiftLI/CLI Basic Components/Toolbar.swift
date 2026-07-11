//
//  Toolbar.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/11.
//


// MARK: - NavigationBarItem.TitleDisplayMode

/// A namespace for navigation-bar configuration values, mirroring SwiftUI's
/// `NavigationBarItem`.
public enum NavigationBarItem {
    /// How the enclosing navigation container lays out its title bar,
    /// mirroring SwiftUI's `NavigationBarItem.TitleDisplayMode`.
    ///
    /// Adapted to the terminal's title bar:
    /// - ``large`` (and ``automatic``) — the title and subtitle each take a
    ///   row of their own, the container's default.
    /// - ``inline`` — the title and subtitle share one compact row.
    public struct TitleDisplayMode: Equatable, Sendable {
        enum Kind: Equatable, Sendable {
            case automatic
            case inline
            case large
        }

        let kind: Kind

        /// The container's default layout (resolves to ``large``).
        public static let automatic = TitleDisplayMode(kind: .automatic)

        /// The title and subtitle share one compact row.
        public static let inline = TitleDisplayMode(kind: .inline)

        /// The title and subtitle each take a row of their own.
        public static let large = TitleDisplayMode(kind: .large)
    }
}

// MARK: - ToolbarPlacement

/// The bars a toolbar modifier applies to, mirroring SwiftUI's
/// `ToolbarPlacement`.
///
/// The terminal draws a single bar — the navigation title bar — so every
/// placement resolves to it.
public struct ToolbarPlacement: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case automatic
        case navigationBar
    }

    let kind: Kind

    /// The main bar of the current context (the navigation title bar).
    public static let automatic = ToolbarPlacement(kind: .automatic)

    /// The navigation title bar drawn above a container's content.
    public static let navigationBar = ToolbarPlacement(kind: .navigationBar)
}

// MARK: - ToolbarRole

/// The purpose of a toolbar, mirroring SwiftUI's `ToolbarRole`.
///
/// The role shapes the title bar's layout: ``editor`` centres the title the
/// way an editor window names its document; the other roles keep it leading.
public struct ToolbarRole: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case automatic
        case navigationStack
        case browser
        case editor
    }

    let kind: Kind

    /// The context's default role (a leading title).
    public static let automatic = ToolbarRole(kind: .automatic)

    /// A navigation title bar with a leading title.
    public static let navigationStack = ToolbarRole(kind: .navigationStack)

    /// A browser-style bar with a leading title.
    public static let browser = ToolbarRole(kind: .browser)

    /// An editor-style bar with a centred title.
    public static let editor = ToolbarRole(kind: .editor)
}

// MARK: - Navigation bar configuration modifiers

public extension View {
    /// Sets how the enclosing navigation container lays out its title bar,
    /// mirroring SwiftUI's `navigationBarTitleDisplayMode(_:)`.
    ///
    /// With ``NavigationBarItem/TitleDisplayMode/inline`` the title and
    /// subtitle share one compact row; ``NavigationBarItem/TitleDisplayMode/large``
    /// (the default) gives each a row of its own. When several layers set a
    /// mode, the active (newest) layer wins. Outside a navigation container
    /// the modifier has no effect.
    ///
    /// ```swift
    /// NavigationStack {
    ///     Text("...")
    ///         .navigationTitle("Settings")
    ///         .navigationBarTitleDisplayMode(.inline)
    /// }
    /// ```
    func navigationBarTitleDisplayMode(_ displayMode: NavigationBarItem.TitleDisplayMode) -> some View {
        NavigationBarConfigWriter(content: AnyView(self)) { $0.titleDisplayMode = displayMode }
    }

    /// Sets the background colour of the enclosing navigation container's
    /// title bar, mirroring SwiftUI's `toolbarBackground(_:for:)`.
    ///
    /// The colour fills every title-bar row across the full terminal width.
    /// The terminal draws a single bar, so every ``ToolbarPlacement`` resolves
    /// to the navigation title bar. Outside a navigation container the
    /// modifier has no effect.
    ///
    /// ```swift
    /// NavigationStack {
    ///     Text("...")
    ///         .navigationTitle("Settings")
    ///         .toolbarBackground(.blue, for: .navigationBar)
    /// }
    /// ```
    func toolbarBackground(_ color: Color, for bars: ToolbarPlacement...) -> some View {
        NavigationBarConfigWriter(content: AnyView(self)) { $0.background = color }
    }

    /// Forces a colour scheme for the enclosing navigation container's title
    /// bar, mirroring SwiftUI's `toolbarColorScheme(_:for:)`.
    ///
    /// `.dark` renders the bar's text in light colours, `.light` in dark
    /// colours — pair it with ``View/toolbarBackground(_:for:)`` so the text
    /// stays readable on the bar's fill. Pass `nil` to return to the
    /// terminal's own scheme. Outside a navigation container the modifier has
    /// no effect.
    ///
    /// ```swift
    /// NavigationStack {
    ///     Text("...")
    ///         .navigationTitle("Settings")
    ///         .toolbarBackground(.blue, for: .navigationBar)
    ///         .toolbarColorScheme(.dark, for: .navigationBar)
    /// }
    /// ```
    func toolbarColorScheme(_ colorScheme: ColorScheme?, for bars: ToolbarPlacement...) -> some View {
        NavigationBarConfigWriter(content: AnyView(self)) { $0.colorScheme = colorScheme }
    }

    /// Sets the purpose of the enclosing navigation container's title bar,
    /// mirroring SwiftUI's `toolbarRole(_:)`.
    ///
    /// ``ToolbarRole/editor`` centres the title; the other roles keep it
    /// leading. Outside a navigation container the modifier has no effect.
    ///
    /// ```swift
    /// NavigationStack {
    ///     Text("...")
    ///         .navigationTitle("Draft.md")
    ///         .toolbarRole(.editor)
    /// }
    /// ```
    func toolbarRole(_ role: ToolbarRole) -> some View {
        NavigationBarConfigWriter(content: AnyView(self)) { $0.role = role }
    }
}

// MARK: - NavigationBarConfigWriter

/// Registers a title-bar setting with the enclosing navigation container
/// while its content lowers, then lowers the content unchanged — the same
/// preference-like flow as ``NavigationTitleWriter``.
struct NavigationBarConfigWriter: View {
    let content: AnyView
    let update: (inout NavigationBarConfig) -> Void

    public var body: some View {
        EmptyView()
    }

    @_spi(RenderingInternals)
    public func addHeader(_ header: String) -> Self {
        NavigationBarConfigWriter(content: content.addHeader(header), update: update)
    }

    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        if let container = EnvironmentStack.current.navigationContainerID {
            NavigationCoordinator.shared.updateBarConfig(for: container, update)
        }
        return content.makeNode()
    }
}

// MARK: - ToolbarItemPlacement

/// Where a toolbar item sits within the title bar, mirroring SwiftUI's
/// `ToolbarItemPlacement`.
///
/// The terminal draws a single bar — the navigation title bar — so every
/// placement resolves to one of its three segments: leading (after the
/// title), centre, or trailing (the right edge). Semantic placements map to
/// the segment SwiftUI would use on a navigation bar.
public struct ToolbarItemPlacement: Equatable, Sendable {
    enum Segment: Equatable, Sendable {
        case leading
        case center
        case trailing
    }

    let segment: Segment

    /// The context's default placement (the trailing segment).
    public static let automatic = ToolbarItemPlacement(segment: .trailing)

    /// The centre of the title bar, in place of the title's slot.
    public static let principal = ToolbarItemPlacement(segment: .center)

    /// Status content in the centre of the title bar.
    public static let status = ToolbarItemPlacement(segment: .center)

    /// Navigation controls in the leading segment.
    public static let navigation = ToolbarItemPlacement(segment: .leading)

    /// The leading segment of the title bar.
    public static let topBarLeading = ToolbarItemPlacement(segment: .leading)

    /// The trailing segment of the title bar.
    public static let topBarTrailing = ToolbarItemPlacement(segment: .trailing)

    /// The most important action, in the trailing segment.
    public static let primaryAction = ToolbarItemPlacement(segment: .trailing)

    /// Secondary actions, in the trailing segment.
    public static let secondaryAction = ToolbarItemPlacement(segment: .trailing)

    /// An action that confirms a task, in the trailing segment.
    public static let confirmationAction = ToolbarItemPlacement(segment: .trailing)

    /// An action that cancels a task, in the leading segment.
    public static let cancellationAction = ToolbarItemPlacement(segment: .leading)

    /// An action with destructive consequences, in the trailing segment.
    public static let destructiveAction = ToolbarItemPlacement(segment: .trailing)

    /// The bottom bar — the terminal has none, so it resolves to the
    /// trailing segment of the title bar.
    public static let bottomBar = ToolbarItemPlacement(segment: .trailing)

    /// The keyboard accessory bar — the terminal has none, so it resolves to
    /// the trailing segment of the title bar.
    public static let keyboard = ToolbarItemPlacement(segment: .trailing)
}

// MARK: - ToolbarContent

/// A toolbar item's resolved form: the segment it sits in and its view.
struct ResolvedToolbarItem {
    let placement: ToolbarItemPlacement
    let view: AnyView
}

/// Content that can populate a toolbar, mirroring SwiftUI's `ToolbarContent`.
///
/// Build it with ``ToolbarItem``, ``ToolbarItemGroup``, and the control-flow
/// forms ``ToolbarContentBuilder`` supports. Custom conformances resolve to
/// no items — compose the built-in types instead.
public protocol ToolbarContent {}

/// The internal resolution hook the built-in ``ToolbarContent`` types
/// implement; the `toolbar` modifier flattens content through it.
protocol PrimitiveToolbarContent {
    var resolvedToolbarItems: [ResolvedToolbarItem] { get }
}

/// Flattens any ``ToolbarContent`` into its resolved items (empty for types
/// the library does not know).
func resolveToolbarItems(_ content: any ToolbarContent) -> [ResolvedToolbarItem] {
    (content as? PrimitiveToolbarContent)?.resolvedToolbarItems ?? []
}

/// A single toolbar item, mirroring SwiftUI's `ToolbarItem`.
///
/// Inside the title bar, a ``Label`` renders icon-only and a ``Button``
/// renders as its plain label (no bordered chrome); ``Text`` renders as-is.
///
/// ```swift
/// .toolbar {
///     ToolbarItem(placement: .primaryAction) {
///         Button("Save") { save() }
///     }
/// }
/// ```
public struct ToolbarItem: ToolbarContent, PrimitiveToolbarContent {
    let placement: ToolbarItemPlacement
    let content: AnyView

    /// Creates a toolbar item rendering `content` at `placement`.
    public init<Content: View>(placement: ToolbarItemPlacement = .automatic, @ViewBuilder content: () -> Content) {
        self.placement = placement
        self.content = AnyView(content())
    }

    var resolvedToolbarItems: [ResolvedToolbarItem] {
        [ResolvedToolbarItem(placement: placement, view: content)]
    }
}

/// A group of toolbar items sharing one placement, mirroring SwiftUI's
/// `ToolbarItemGroup`.
///
/// Each view in `content` becomes its own item in the placement's segment.
///
/// ```swift
/// .toolbar {
///     ToolbarItemGroup(placement: .primaryAction) {
///         Button("Copy") { copy() }
///         Button("Paste") { paste() }
///     }
/// }
/// ```
public struct ToolbarItemGroup: ToolbarContent, PrimitiveToolbarContent {
    let placement: ToolbarItemPlacement
    let children: [any View]

    /// Creates a group rendering each view in `content` at `placement`.
    public init<Content: View>(placement: ToolbarItemPlacement = .automatic, @ViewBuilder content: () -> Content) {
        self.placement = placement
        self.children = content()._flattenedChildren()
    }

    var resolvedToolbarItems: [ResolvedToolbarItem] {
        children.map { ResolvedToolbarItem(placement: placement, view: AnyView(erasing: $0)) }
    }
}

/// Type-erased toolbar content; the currency type every
/// ``ToolbarContentBuilder`` form produces.
public struct AnyToolbarContent: ToolbarContent, PrimitiveToolbarContent {
    let items: [ResolvedToolbarItem]

    /// Creates an erased copy of `content`.
    public init(_ content: any ToolbarContent) {
        self.items = resolveToolbarItems(content)
    }

    init(items: [ResolvedToolbarItem]) {
        self.items = items
    }

    var resolvedToolbarItems: [ResolvedToolbarItem] { items }
}

// MARK: - ToolbarContentBuilder

/// A result builder constructing toolbar content from closures, mirroring
/// SwiftUI's `ToolbarContentBuilder`.
///
/// Every expression is erased to ``AnyToolbarContent``, so blocks take any
/// number of items — SwiftUI's ten-view ceiling does not apply — and `if`,
/// `if/else`, `switch`, and `for` all work.
@resultBuilder
public struct ToolbarContentBuilder {
    /// Combines any number of items into one content — no ten-item limit.
    public static func buildBlock(_ components: AnyToolbarContent...) -> AnyToolbarContent {
        AnyToolbarContent(items: components.flatMap { $0.items })
    }

    /// A toolbar-content expression is erased so blocks stay homogeneous.
    public static func buildExpression(_ content: any ToolbarContent) -> AnyToolbarContent {
        AnyToolbarContent(content)
    }

    /// Produces content for an `if` statement without an `else`.
    public static func buildOptional(_ component: AnyToolbarContent?) -> AnyToolbarContent {
        component ?? AnyToolbarContent(items: [])
    }

    /// Produces content for the `true` branch of an `if`/`else`.
    public static func buildEither(first component: AnyToolbarContent) -> AnyToolbarContent {
        component
    }

    /// Produces content for the `false` branch of an `if`/`else`.
    public static func buildEither(second component: AnyToolbarContent) -> AnyToolbarContent {
        component
    }

    /// Concatenates the items a `for` loop produces.
    public static func buildArray(_ components: [AnyToolbarContent]) -> AnyToolbarContent {
        AnyToolbarContent(items: components.flatMap { $0.items })
    }

    /// Passes through content guarded by an `if #available` check.
    public static func buildLimitedAvailability(_ component: AnyToolbarContent) -> AnyToolbarContent {
        component
    }
}

// MARK: - toolbar modifier

public extension View {
    /// Populates the enclosing navigation container's title bar with items,
    /// mirroring SwiftUI's `toolbar(content:)`.
    ///
    /// Items render inside the title bar by segment: leading items after the
    /// title, centre items mid-bar, trailing items at the right edge. Inside
    /// the bar a ``Label`` renders icon-only and a ``Button`` as its plain
    /// label; ``Text`` renders as-is. Several `toolbar` modifiers accumulate,
    /// and the active (newest) layer's items win. Outside a navigation
    /// container the modifier has no effect.
    ///
    /// ```swift
    /// NavigationStack {
    ///     Text("...")
    ///         .navigationTitle("Files")
    ///         .toolbar {
    ///             ToolbarItem(placement: .principal) { Text("3 selected") }
    ///             ToolbarItemGroup(placement: .primaryAction) {
    ///                 Button("Copy") { copy() }
    ///                 Button("Delete") { delete() }
    ///             }
    ///         }
    /// }
    /// ```
    func toolbar(@ToolbarContentBuilder content: () -> some ToolbarContent) -> some View {
        let items = resolveToolbarItems(content())
        return NavigationBarConfigWriter(content: AnyView(self)) { $0.toolbarItems += items }
    }
}
