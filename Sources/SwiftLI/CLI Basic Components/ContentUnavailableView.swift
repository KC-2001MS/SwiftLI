//
//  ContentUnavailableView.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/09.
//


/// A view that describes an empty state — no results, no data, nothing to show.
///
/// Mirrors SwiftUI's `ContentUnavailableView`: an optional icon, a bold title,
/// and an optional dimmed description, stacked for display when a list or
/// screen would otherwise be blank.
///
/// ```swift
/// ContentUnavailableView(
///     "No Results",
///     image: "🔍",
///     description: "Try a different search term."
/// )
/// .render()
/// ```
public struct ContentUnavailableView: View {
    let style: TextStyle
    let image: String
    let title: String
    let description: String?

    /// Initializer used internally for modifier chaining.
    init(style: TextStyle, image: String, title: String, description: String?) {
        self.style = style
        self.image = image
        self.title = title
        self.description = description
    }

    /// Creates an empty-state view.
    ///
    /// - Parameters:
    ///   - title: The localized headline describing what is unavailable.
    ///   - image: An optional icon string (e.g. an emoji) shown above the title.
    ///     Pass `""` to omit it.
    ///   - description: An optional localized sentence giving more detail.
    public init(
        _ title: LocalizedStringKey,
        image: String = "",
        description: LocalizedStringKey? = nil
    ) {
        self.style = .plain
        self.image = image
        self.title = String(localized: title.localizationValue)
        self.description = description.map { String(localized: $0.localizationValue) }
    }

    /// The rendered content of the empty-state view: an optional icon, a bold title, and an optional dimmed description.
    public var body: some View {
        if !image.isEmpty {
            Text(content: image)
        }
        Text(content: title).bold()
        if let description {
            Text(content: description).forgroundColor(.eight_bit(245))
        }
    }

    @_spi(RenderingInternals)
    public func applyingStyle(_ style: TextStyle) -> Self {
        .init(style: self.style.inheriting(style), image: image, title: title, description: description)
    }

    /// Lowers the empty-state view by building its body, then cascading the
    /// view's own style onto the resulting node.
    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        let node = body.makeNode()
        return style.isPlain ? node : node.applyingStyle(style)
    }
}
