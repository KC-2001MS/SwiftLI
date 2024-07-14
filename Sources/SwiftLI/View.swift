//
//  View.swift
//
//
//  Created by Keisuke Chinone on 2024/05/27.
//


/// View to display text in terminal
///
/// This is the most basic view that displays text in the terminal.
///
/// To display the string you want to display, declare it with the init(_ string: String) initializer.
/// ```swift
/// let text = Text("Hello SwiftLI!")
/// text.render()
/// ```
/// To display a character multiple times in a row, declare it with the init(repeating: Character,count: Int) initializer.
/// ```swift
/// let text = Text(repeating: "+", count: 10)
/// text.render()
/// ```
///  In addition, you can change the text style of the view.To change, adapt the respective modifier. Below is an example of changing the text color to red and bold text.
/// ```swift
/// let text = Text("Hello SwiftLI!").forgroundColor(.red).bold()
/// text.render()
/// ```
public struct Text: View {
    internal let header: String
    
    let content: String
    
    let footer: Bool
    /// Creates a text view that is displayed in the terminal.
    /// - Parameter string: String to be displayed in the terminal
    public init(_ string: String) {
        self.header = ""
        self.content = string
        self.footer = false
    }
    /// Creates a text view that is displayed in the terminal.
    /// - Parameters:
    ///   - repeating: String to be repeated
    ///   - count: Number of times text is repeated
    public init(
        repeating: Character,
        count: Int
    ) {
        self.header = ""
        self.content = String(repeating: repeating, count: count)
        self.footer = false
    }
    
    init(
        header: String,
        repeating: Character,
        count: Int,
        footer: Bool = false
    ) {
        self.header = header
        self.content = String(repeating: repeating, count: count)
        self.footer = footer
    }
    /// Initializer to realize method chain
    /// - Parameters:
    ///   - header: Hetter to specify display style
    ///   - content: String to display
    init(
        header: String,
        content: String,
        footer: Bool = false
    ) {
        self.header = "\(header)"
        self.content = content
        self.footer = footer
    }
    /// What the view displays
    public var body: [any View] {
        return []
    }
    /// Methods for rendering text
    public func render() {
        print("\(header)\(content)\u{001B}[0m", terminator: footer ? "\n" : "")
    }
    /// Modifier to adapt foreground color to existing text
    /// - Parameter color: Color to be specified as foreground color
    /// - Returns: Text view with foreground color adaptation
    public func forgroundColor(_ color: Color) -> Text {
        return .init(header: "\(header)\u{001B}[3\(color.ansi)m", content: content, footer: footer)
    }
    /// Modifier to adapt background color to existing text
    /// - Parameter color: Color to be specified as background color
    /// - Returns: Text view with background color adaptation
    public func background(_ color: Color) -> Text {
        return .init(header: "\(header)\u{001B}[4\(color.ansi)m", content: content, footer: footer)
    }
    /// Applies a bold font weight to the text.
    /// - Returns: Bold text.
    public func bold() -> Text {
        return .init(header: "\(header)\u{001B}[1m", content: content, footer: footer)
    }
    /// Applies a bold font weight to the text.
    /// - Parameter isActive: A Boolean value that indicates whether text has bold styling.
    /// - Returns: Bold text.
    public func bold(_ isActive: Bool) -> Text {
        return .init(header: isActive ? "\(header)\u{001B}[1m" : "\(header)", content: content, footer: footer)
    }
    /// Sets the font weight of the text.
    /// - Parameter weight: One of the available font weights.
    /// - Returns: Text view with adapted text weighting
    public func fontWeight(_ weight: Weight) -> Text {
        if weight == .default {
            return .init(header: header, content: content, footer: footer)
        } else {
            return .init(header: "\(header)\u{001B}[\(weight.rawValue)m", content: content, footer: footer)
        }
    }
    /// Applies italics to the text.
    /// - Returns: Italic text.
    public func italic() -> Text {
        return .init(header: "\(header)\u{001B}[3m", content: content, footer: footer)
    }
    /// Applies italics to the text.
    /// - Parameter isActive: A Boolean value that indicates whether italic styling is added.
    /// - Returns: Italic text.
    public func italic(_ isActive: Bool) -> Text {
        return .init(header: isActive ? "\(header)\u{001B}[3m" : "\(header)", content: content, footer: footer)
    }
    /// Applies an underline to the text.
    /// - Returns: Text with a line.
    public func underline() -> Text {
        return .init(header: "\(header)\u{001B}[4m", content: content, footer: footer)
    }
    /// Applies an underline to the text.
    /// - Parameter isActive: A Boolean value that indicates whether underline styling is added. The default value is true.
    /// - Returns: Text with a line.
    public func underline(_ isActive: Bool) -> Text {
        return .init(header: isActive ? "\(header)\u{001B}[4m" : "\(header)", content: content, footer: footer)
    }
    /// Applies a blink to the text.
    /// - Parameter style: Flashing Method
    /// - Returns: Blinking text.
    public func blink(_ style: BlinkStyle) -> Text {
        if style == .none {
            return .init(header: header, content: content, footer: footer)
        } else {
            return .init(header: "\(header)\u{001B}[\(style.rawValue)m", content: content, footer: footer)
        }
    }
    /// Hides this view unconditionally.
    /// - Returns: A hidden view.
    public func hidden() -> Text {
        return .init(header: "\(header)\u{001B}[8m", content: content, footer: footer)
    }
    /// Hides this view unconditionally.
    /// - Parameter isActive: A Boolean value that indicates whether text has hiden.
    /// - Returns: A hidden view.
    public func hidden(_ isActive: Bool) -> Text {
        return .init(header: isActive ? "\(header)\u{001B}[8m" : "\(header)", content: content, footer: footer)
    }
    /// Applies a strikethrough to the text.
    /// - Returns: Text with a line through its center.
    public func strikethrough() -> Text {
        return .init(header: "\(header)\u{001B}[9m", content: content, footer: footer)
    }
    /// Applies a strikethrough to the text.
    /// - Parameter isActive: A Boolean value that indicates whether the text has a strikethrough applied.
    /// - Returns: Text with a line through its center.
    public func strikethrough(_ isActive: Bool) -> Text {
        return .init(header: isActive ? "\(header)\u{001B}[9m" : "\(header)", content: content, footer: footer)
    }
    /// Whether to break the View at the end
    /// - Parameter newLine: whether or not to start a new line
    /// - Returns: Adapted view
    public func newLine(_ newLine: Bool = true) -> Text {
        return .init(header: header, content: content, footer: newLine)
    }
}

/// A type that represents part of your CLT’s user interface and provides modifiers that you use to configure views.
public protocol View {
    @ViewBuilder
    /// What the view displays
    var body: [View] { get }
    /// Methods for rendering text
    func render()
}

public extension View {
    /// Default implementation of the render function
    func render() {
        body.forEach {
            $0.render()
        }
    }
}
