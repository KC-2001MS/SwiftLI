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
    let header: String
    let image: String
    let title: String
    let description: String?

    /// Initializer used internally for modifier chaining.
    init(header: String, image: String, title: String, description: String?) {
        self.header = header
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
        self.header = ""
        self.image = image
        self.title = String(localized: title.localizationValue)
        self.description = description.map { String(localized: $0.localizationValue) }
    }

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
    public func addHeader(_ header: String) -> Self {
        .init(header: header + self.header, image: image, title: title, description: description)
    }

    /// Lowers the empty-state view by building its body, then cascading the
    /// view's own style header onto the resulting node.
    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        let node = body.makeNode()
        return header.isEmpty ? node : node.applyingHeader(header)
    }
}
