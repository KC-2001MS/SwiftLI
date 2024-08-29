//
//  Label.swift
//  SwiftLI
//  
//  Created by Keisuke Chinone on 2024/07/23.
//


public struct Label: View {
    let header: String
    
    let image: String
    
    let title: String
    
    let footer: Bool
    
    let style: LabelStyle

    /// Initializer to realize method chain
    /// - Parameters:
    ///   - header: Hetter to specify display style
    ///   - title: String to display
    init(
        header: String,
        title: String,
        image: String,
        footer: Bool = false,
        style: LabelStyle = .automatic
    ) {
        self.header = "\(header)"
        self.title = title
        self.image = image
        self.footer = footer
        self.style = style
    }
    
    /// Creates a label view that is displayed in the terminal.
    /// - Parameters:
    ///   - title: Label Title
    ///   - unicodeImage: Unicode numbers for visual representation
    public init(
        _ title: LocalizedStringKey,
        unicodeImage: Int
    ) {
        let image: String
        // UnicodeScalarで初期化できるか確認
        if let scalar = UnicodeScalar(unicodeImage) {
            image = String(scalar)
        } else {
            // 初期化できない場合は空文字列を返す
            image = ""
        }
        self.header = ""
        self.image = image
        self.title = String(localized: title.localizationValue)
        self.footer = false
        self.style = .automatic
    }
    
    /// Creates a label view that is displayed in the terminal.
    /// - Parameters:
    ///   - image: String for visual representation
    ///   - title: Label Title
    public init(
        image: String,
        title: LocalizedStringKey
    ) {
        self.header = ""
        self.image = image
        self.title = String(localized: title.localizationValue)
        self.footer = false
        self.style = .automatic
    }
    
    /// What the view displays
    public var body: [any View] {
        return style.makeBody(configuration: LabelStyleConfiguration(icon: Text(content: image), title: Text(content: title)))
    }

    /// Methods for rendering text
    public func render() {
        Group(header: header, contents: body, footer: footer).render()
    }
    
    public func labelStyle(_ style: LabelStyle) -> Self {
        return .init(header: self.header, title: self.header, image: self.image, footer: self.footer, style: style)
    }

    /// Modifier to adapt foreground color to existing text
    /// - Parameter color: Color to be specified as foreground color
    /// - Returns: Text view with foreground color adaptation
    public func forgroundColor(_ color: Color) -> Self {
        return .init(header: "\(header)\u{001B}[3\(color.ansi)m", title: title, image: image, footer: footer)
    }
    /// Modifier to adapt background color to existing text
    /// - Parameter color: Color to be specified as background color
    /// - Returns: Text view with background color adaptation
    public func background(_ color: Color) -> Self {
        return .init(header: "\(header)\u{001B}[4\(color.ansi)m", title: title, image: image, footer: footer)
    }
    /// Applies a bold font weight to the text.
    /// - Returns: Bold text.
    public func bold() -> Self {
        return .init(header: "\(header)\u{001B}[1m", title: title, image: image, footer: footer)
    }
    /// Applies a bold font weight to the text.
    /// - Parameter isActive: A Boolean value that indicates whether text has bold styling.
    /// - Returns: Bold text.
    public func bold(_ isActive: Bool) -> Self {
        return .init(header: isActive ? "\(header)\u{001B}[1m" : "\(header)", title: title, image: image, footer: footer)
    }
    /// Sets the font weight of the text.
    /// - Parameter weight: One of the available font weights.
    /// - Returns: Text view with adapted text weighting
    public func fontWeight(_ weight: Weight) -> Self {
        if weight == .default {
            return .init(header: header, title: title, image: image, footer: footer)
        } else {
            return .init(header: "\(header)\u{001B}[\(weight.rawValue)m", title: title, image: image, footer: footer)
        }
    }
    /// Applies italics to the text.
    /// - Returns: Italic text.
    public func italic() -> Self {
        return .init(header: "\(header)\u{001B}[3m", title: title, image: image, footer: footer)
    }
    /// Applies italics to the text.
    /// - Parameter isActive: A Boolean value that indicates whether italic styling is added.
    /// - Returns: Italic text.
    public func italic(_ isActive: Bool) -> Self {
        return .init(header: isActive ? "\(header)\u{001B}[3m" : "\(header)", title: title, image: image, footer: footer)
    }
    /// Applies an underline to the text.
    /// - Returns: Text with a line.
    public func underline() -> Self {
        return .init(header: "\(header)\u{001B}[4m", title: title, image: image, footer: footer)
    }
    /// Applies an underline to the text.
    /// - Parameter isActive: A Boolean value that indicates whether underline styling is added. The default value is true.
    /// - Returns: Text with a line.
    public func underline(_ isActive: Bool) -> Self {
        return .init(header: isActive ? "\(header)\u{001B}[4m" : "\(header)", title: title, image: image, footer: footer)
    }
    /// Applies a blink to the text.
    /// - Parameter style: Flashing Method
    /// - Returns: Blinking text.
    public func blink(_ style: BlinkStyle) -> Self {
        if style == .none {
            return .init(header: header, title: title, image: image, footer: footer)
        } else {
            return .init(header: "\(header)\u{001B}[\(style.rawValue)m", title: title, image: image, footer: footer)
        }
    }
    /// Hides this view unconditionally.
    /// - Returns: A hidden view.
    public func hidden() -> Self {
        return .init(header: "\(header)\u{001B}[8m", title: title, image: image, footer: footer)
    }
    /// Hides this view unconditionally.
    /// - Parameter isActive: A Boolean value that indicates whether text has hiden.
    /// - Returns: A hidden view.
    public func hidden(_ isActive: Bool) -> Self {
        return .init(header: isActive ? "\(header)\u{001B}[8m" : "\(header)", title: title, image: image, footer: footer)
    }
    /// Applies a strikethrough to the text.
    /// - Returns: Text with a line through its center.
    public func strikethrough() -> Self {
        return .init(header: "\(header)\u{001B}[9m", title: title, image: image, footer: footer)
    }
    /// Applies a strikethrough to the text.
    /// - Parameter isActive: A Boolean value that indicates whether the text has a strikethrough applied.
    /// - Returns: Text with a line through its center.
    public func strikethrough(_ isActive: Bool) -> Self {
        return .init(header: isActive ? "\(header)\u{001B}[9m" : "\(header)", title: title, image: image, footer: footer)
    }
    /// Whether to break the View at the end
    /// - Parameter newLine: whether or not to start a new line
    /// - Returns: Adapted view
    public func newLine(_ newLine: Bool = true) -> Self {
        return .init(header: header, title: title, image: image, footer: newLine)
    }
}
