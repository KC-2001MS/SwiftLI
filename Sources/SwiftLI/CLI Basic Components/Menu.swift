//
//  Menu.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/10.
//

// MARK: - MenuStyle protocol

/// The values passed to ``MenuStyle/makeBody(configuration:)`` when rendering.
public struct MenuStyleConfiguration {
    /// The menu's heading view, or `nil` when the menu has no title.
    public let label: AnyView?
    /// The menu items, stacked vertically and not yet indented.
    public let content: AnyView
}

/// A type that defines the appearance of a ``Menu``.
///
/// Conform to `MenuStyle` and apply it with ``Menu/menuStyle(_:)`` (or
/// ``View/menuStyle(_:)`` for a whole subtree). The default style is
/// ``DefaultMenuStyle``.
public protocol MenuStyle: Sendable {
    /// The type of view produced by this style.
    associatedtype Body: View

    /// Returns a view that represents the menu.
    ///
    /// - Parameter configuration: The menu's heading and stacked items.
    @ViewBuilder
    func makeBody(configuration: MenuStyleConfiguration) -> Body
}

/// The default menu style — a bold heading with the items indented two
/// columns beneath it. Equivalent to ``MenuStyle/automatic``.
public struct DefaultMenuStyle: MenuStyle {
    /// Creates a default menu style.
    public init() {}

    /// Returns a view that renders the menu with a bold heading above indented items.
    ///
    /// - Parameter configuration: The menu's heading and stacked items.
    public func makeBody(configuration: MenuStyleConfiguration) -> some View {
        if let label = configuration.label { label.bold() }
        configuration.content.padding(.leading, 2)
    }
}

public extension MenuStyle where Self == DefaultMenuStyle {
    /// The default menu style: a bold heading above indented items.
    static var automatic: Self { .init() }
}

// MARK: - AnyMenuStyle (type erasure)

/// A type-erased ``MenuStyle`` whose erased result is an ``AnyView`` — a
/// plain composition of views, matching how ``AnyToggleStyle`` works.
struct AnyMenuStyle: MenuStyle, @unchecked Sendable {
    private let _makeBody: (MenuStyleConfiguration) -> any View

    init<S: MenuStyle>(_ style: S) {
        _makeBody = { style.makeBody(configuration: $0) }
    }

    func makeBody(configuration: MenuStyleConfiguration) -> AnyView {
        AnyView(erasing: _makeBody(configuration))
    }
}

// MARK: - Menu

/// A titled group of actions, composed of ``Button``s (or any other views)
/// stacked under a bold heading.
///
/// `Menu` is the terminal analog of SwiftUI's `Menu`: instead of popping over,
/// its items are always visible, indented under the title. Focus flows through
/// the contained buttons with <kbd>Tab</kbd> as usual.
///
/// ```swift
/// Menu("File") {
///     Button("New") { create() }
///     Button("Open…") { open() }
///     Button("Delete", role: .destructive) { delete() }
/// }
/// ```
public struct Menu: View {
    let title: AnyView?
    let content: [any View]
    /// The explicitly applied style, or `nil` to resolve from the environment.
    let style: AnyMenuStyle?

    /// Creates a menu with a localized title.
    /// - Parameters:
    ///   - title: The heading shown above the items.
    ///   - content: A ``ViewBuilder`` producing the menu items — typically
    ///     ``Button``s.
    public init<Content: View>(
        _ title: LocalizedStringKey = "",
        @ViewBuilder content: () -> Content
    ) {
        let resolved = title.resolve()
        self.title = resolved.isEmpty ? nil : AnyView(Text(content: resolved))
        self.content = content()._flattenedChildren()
        self.style = nil
    }

    /// Creates a menu with a custom label view as its heading.
    /// - Parameters:
    ///   - content: A ``ViewBuilder`` producing the menu items.
    ///   - label: A ``ViewBuilder`` producing the heading.
    public init<Content: View, Label: View>(
        @ViewBuilder content: () -> Content,
        @ViewBuilder label: () -> Label
    ) {
        self.title = AnyView(label())
        self.content = content()._flattenedChildren()
        self.style = nil
    }

    // Internal init for style chaining.
    init(title: AnyView?, content: [any View], style: AnyMenuStyle?) {
        self.title = title
        self.content = content
        self.style = style
    }

    /// The rendered view produced by applying the resolved menu style.
    public var body: some View {
        // Nearest wins: instance style, then subtree environment, then default.
        let resolvedStyle = style ?? EnvironmentStack.current.menuStyle ?? AnyMenuStyle(DefaultMenuStyle())
        resolvedStyle.makeBody(configuration: MenuStyleConfiguration(
            label: title,
            content: AnyView(VStack(alignment: .leading, spacing: 0, children: content))
        ))
    }

    /// Sets the style used to compose this menu.
    ///
    /// - Parameter newStyle: A value conforming to ``MenuStyle``.
    public func menuStyle(_ newStyle: some MenuStyle) -> Self {
        Self(title: title, content: content, style: AnyMenuStyle(newStyle))
    }
}
