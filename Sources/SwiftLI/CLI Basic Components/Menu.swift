//
//  Menu.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/10.
//

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

    /// Creates a menu with a localized title.
    /// - Parameters:
    ///   - title: The heading shown above the items.
    ///   - content: A ``ViewBuilder`` producing the menu items — typically
    ///     ``Button``s.
    public init<Content: View>(
        _ title: LocalizedStringKey = "",
        @ViewBuilder content: () -> Content
    ) {
        let resolved = String(localized: title.localizationValue)
        self.title = resolved.isEmpty ? nil : AnyView(Text(content: resolved))
        self.content = content()._flattenedChildren()
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
    }

    public var body: some View {
        if let title { title.bold() }
        VStack(alignment: .leading, spacing: 0, children: items)
    }

    /// The menu items, indented two columns under the heading.
    private var items: [any View] {
        content.map { $0.padding(.leading, 2) }
    }
}
