//
//  Label.swift
//  SwiftLI
//  
//  Created by Keisuke Chinone on 2024/07/23.
//


/// A view that pairs an icon with a text title.
///
/// `Label` combines an icon — either a Unicode scalar by code point or a plain
/// string — with a human-readable title. Its layout is determined by a
/// ``LabelStyle``, which defaults to ``DefaultLabelStyle`` (icon · space · title).
///
/// ```swift
/// // Icon from a Unicode code point
/// Label("Open Folder", unicodeImage: 0x1F4C2).render()
/// // 📂 Open Folder
///
/// // Icon from a string
/// Label(image: "★", title: "Favorite").render()
/// // ★ Favorite
/// ```
///
/// ## Customizing the layout
///
/// Apply ``labelStyle(_:)`` to change how the icon and title are arranged:
///
/// ```swift
/// Label("File", unicodeImage: 0x1F4C4)
///     .labelStyle(.titleOnly)
///     .render()
/// // File
/// ```
///
/// Built-in styles: ``DefaultLabelStyle/automatic``, ``IconOnlyLabelStyle/iconOnly``,
/// ``TitleOnlyLabelStyle/titleOnly``, ``TitleAndIconLabelStyle/titleAndIcon``.
public struct Label: View {
    let header: String

    let image: String

    let title: String

    let style: any LabelStyle

    /// Initializer used internally for modifier chaining.
    init(
        header: String,
        title: String,
        image: String,
        style: any LabelStyle = DefaultLabelStyle()
    ) {
        self.header = "\(header)"
        self.title = title
        self.image = image
        self.style = style
    }

    /// Creates a label with a title string and an icon specified by Unicode scalar value.
    ///
    /// If `unicodeImage` does not represent a valid Unicode scalar, the icon is
    /// rendered as an empty string.
    ///
    /// - Parameters:
    ///   - title: The localized title displayed next to the icon.
    ///   - unicodeImage: The Unicode code point of the icon character (e.g. `0x1F4C2` for 📂).
    public init(
        _ title: LocalizedStringKey,
        unicodeImage: Int
    ) {
        let image: String
        if let scalar = UnicodeScalar(unicodeImage) {
            image = String(scalar)
        } else {
            image = ""
        }
        self.header = ""
        self.image = image
        self.title = String(localized: title.localizationValue)
        self.style = DefaultLabelStyle()
    }

    /// Creates a label with an explicit icon string and a title.
    ///
    /// - Parameters:
    ///   - image: A string used as the icon (e.g. an emoji or ASCII art).
    ///   - title: The localized title displayed next to the icon.
    public init(
        image: String,
        title: LocalizedStringKey
    ) {
        self.header = ""
        self.image = image
        self.title = String(localized: title.localizationValue)
        self.style = DefaultLabelStyle()
    }

    public var body: some View {
        AnyView(erasing: style.makeBody(configuration: LabelStyleConfiguration(
            icon: AnyView(Text(content: image)),
            title: AnyView(Text(content: title))
        )))
    }

    @_spi(RenderingInternals)
    public func addHeader(_ header: String) -> Self {
        .init(header: header + self.header, title: self.title, image: self.image, style: self.style)
    }

    /// Lowers the label by building its style body, then cascading the label's
    /// own style header onto the resulting node.
    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        let node = style.makeBody(configuration: LabelStyleConfiguration(
            icon: AnyView(Text(content: image)),
            title: AnyView(Text(content: title))
        )).makeNode()
        return header.isEmpty ? node : node.applyingHeader(header)
    }

    /// Changes the style used to lay out the icon and title.
    ///
    /// - Parameter newStyle: The new ``LabelStyle`` to apply.
    /// - Returns: A copy of the label using `newStyle`.
    public func labelStyle(_ newStyle: some LabelStyle) -> Self {
        return .init(header: self.header, title: self.title, image: self.image, style: newStyle)
    }
}
