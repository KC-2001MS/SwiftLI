//
//  GroupBox.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/09.
//


// MARK: - GroupBoxStyle protocol

/// The values passed to ``GroupBoxStyle/makeBody(configuration:)`` when rendering.
public struct GroupBoxStyleConfiguration {
    /// The group box's title view, or `nil` when the box has no title.
    public let label: AnyView?
    /// The grouped content, stacked vertically.
    public let content: AnyView
}

/// A type that defines the appearance of a ``GroupBox``.
///
/// Conform to `GroupBoxStyle` and apply it with ``GroupBox/groupBoxStyle(_:)``
/// (or ``View/groupBoxStyle(_:)`` for a whole subtree). The default style is
/// ``DefaultGroupBoxStyle``.
public protocol GroupBoxStyle: Sendable {
    /// The type of view produced by this style.
    associatedtype Body: View

    /// Returns a view that represents the group box.
    ///
    /// - Parameter configuration: The box's title and grouped content.
    @ViewBuilder
    func makeBody(configuration: GroupBoxStyleConfiguration) -> Body
}

/// The default group box style — a bold title above the content, wrapped in a
/// padded rounded border. Equivalent to ``GroupBoxStyle/automatic``.
public struct DefaultGroupBoxStyle: GroupBoxStyle {
    public init() {}

    public func makeBody(configuration: GroupBoxStyleConfiguration) -> some View {
        var items: [any View] = []
        if let label = configuration.label {
            items.append(label.bold())
        }
        items.append(configuration.content)
        return VStack(alignment: .leading, spacing: 0, children: items)
            .padding()
            .border(.rounded)
    }
}

public extension GroupBoxStyle where Self == DefaultGroupBoxStyle {
    /// The default group box style: a bold title in a padded rounded border.
    static var automatic: Self { .init() }
}

// MARK: - AnyGroupBoxStyle (type erasure)

/// A type-erased ``GroupBoxStyle`` whose erased result is an ``AnyView`` — a
/// plain composition of views, matching how ``AnyToggleStyle`` works.
struct AnyGroupBoxStyle: GroupBoxStyle, @unchecked Sendable {
    private let _makeBody: (GroupBoxStyleConfiguration) -> any View

    init<S: GroupBoxStyle>(_ style: S) {
        _makeBody = { style.makeBody(configuration: $0) }
    }

    func makeBody(configuration: GroupBoxStyleConfiguration) -> AnyView {
        AnyView(erasing: _makeBody(configuration))
    }
}

// MARK: - GroupBox

/// A titled, bordered container that visually groups related content.
///
/// Mirrors SwiftUI's `GroupBox`: an optional bold title sits above the grouped
/// content, and the whole thing is wrapped in a rounded border with padding.
/// The layout is chosen by a ``GroupBoxStyle`` — ``DefaultGroupBoxStyle`` by
/// default.
///
/// ```swift
/// GroupBox("Network") {
///     Text("Status: Connected")
///     Text("Latency: 24 ms")
/// }
/// .render()
/// ```
public struct GroupBox: View {
    let title: String?
    let content: [any View]
    /// The explicitly applied style, or `nil` to resolve from the environment.
    let style: AnyGroupBoxStyle?

    /// Creates a group box with an optional title.
    ///
    /// - Parameters:
    ///   - title: An optional localized title shown at the top of the box.
    ///   - content: A ``ViewBuilder`` producing the grouped content.
    public init<Content: View>(_ title: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) {
        self.title = title.map { String(localized: $0.localizationValue) }
        self.content = content()._flattenedChildren()
        self.style = nil
    }

    // Internal init for style chaining.
    init(title: String?, content: [any View], style: AnyGroupBoxStyle?) {
        self.title = title
        self.content = content
        self.style = style
    }

    public var body: some View {
        // Nearest wins: instance style, then subtree environment, then default.
        let resolvedStyle = style ?? EnvironmentStack.current.groupBoxStyle ?? AnyGroupBoxStyle(DefaultGroupBoxStyle())
        resolvedStyle.makeBody(configuration: GroupBoxStyleConfiguration(
            label: title.map { AnyView(Text(content: $0)) },
            content: AnyView(VStack(alignment: .leading, spacing: 0, children: content))
        ))
    }

    /// Sets the style used to compose this group box.
    ///
    /// - Parameter newStyle: A value conforming to ``GroupBoxStyle``.
    public func groupBoxStyle(_ newStyle: some GroupBoxStyle) -> Self {
        Self(title: title, content: content, style: AnyGroupBoxStyle(newStyle))
    }
}
