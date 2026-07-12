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
    let textStyle: TextStyle

    let image: String

    let title: String

    /// The explicitly applied style, or `nil` to resolve from the environment.
    let style: AnyLabelStyle?

    /// Initializer used internally for modifier chaining.
    init(
        textStyle: TextStyle,
        title: String,
        image: String,
        style: AnyLabelStyle? = nil
    ) {
        self.textStyle = textStyle
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
        self.textStyle = .plain
        self.image = image
        self.title = title.resolve()
        self.style = nil
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
        self.textStyle = .plain
        self.image = image
        self.title = title.resolve()
        self.style = nil
    }

    /// The style to render with: the explicitly applied one, else the nearest
    /// ``View/labelStyle(_:)`` in the environment, else the default.
    private var resolvedStyle: AnyLabelStyle {
        style ?? EnvironmentStack.current.labelStyle ?? AnyLabelStyle(DefaultLabelStyle())
    }

    /// The rendered output of the label, produced by the resolved label style.
    public var body: some View {
        resolvedStyle.makeBody(configuration: LabelStyleConfiguration(
            icon: AnyView(Text(content: image)),
            title: AnyView(Text(content: title))
        ))
    }

    @_spi(RenderingInternals)
    public func applyingStyle(_ style: TextStyle) -> Self {
        .init(textStyle: textStyle.inheriting(style), title: self.title, image: self.image, style: self.style)
    }

    /// Lowers the label by building its style body, then cascading the label's
    /// own text style onto the resulting node.
    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        let node = resolvedStyle.makeBody(configuration: LabelStyleConfiguration(
            icon: AnyView(Text(content: image)),
            title: AnyView(Text(content: title))
        )).makeNode()
        return textStyle.isPlain ? node : node.applyingStyle(textStyle)
    }

    /// Changes the style used to lay out the icon and title.
    ///
    /// - Parameter newStyle: The new ``LabelStyle`` to apply.
    /// - Returns: A copy of the label using `newStyle`.
    public func labelStyle(_ newStyle: some LabelStyle) -> Self {
        return .init(textStyle: self.textStyle, title: self.title, image: self.image, style: AnyLabelStyle(newStyle))
    }
}
