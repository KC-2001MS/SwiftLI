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
public struct Text: View, Sendable, Equatable {
    let header: String
    
    let contents: Array<String>
    
    let footer: Bool
    /// Creates a text view that is displayed in the terminal.
    /// - Parameter string: String to be displayed in the terminal
    public init(_ string: String) {
        self.header = ""
        self.contents = [string]
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
        self.contents = [String(repeating: repeating, count: count)]
        self.footer = false
    }
    
    init(
        header: String,
        repeating: Character,
        count: Int,
        footer: Bool = false
    ) {
        self.header = header
        self.contents = [String(repeating: repeating, count: count)]
        self.footer = footer
    }

    init(
        header: String,
        contents: Array<String>,
        footer: Bool = false
    ) {
        self.header = "\(header)"
        self.contents = contents
        self.footer = footer
    }
    
    init(
        header: String = "",
        content: String,
        footer: Bool = false
    ) {
        self.header = "\(header)"
        self.contents = [content]
        self.footer = footer
    }
    /// What the view displays
    public var body: [any View] {
        return []
    }
    
    public func addHeader(_ header: String) -> Self {
        return Text(header: header + self.header, contents: contents, footer: footer)
    }

    /// Methods for rendering text
    public func render() {
        for content in contents {
            print("\(header)\(content)\u{001B}[0m", terminator: "")
        }
        print("", terminator: footer ? "\n" : "")
    }
    
    
    static func +(left: Self, right: Self) -> Self {
        let leftContents = left.contents.map({ left.header + $0 })
        let rightContents = right.contents.map({ right.header + $0 })
        return Text(header: "", contents: leftContents + rightContents, footer: false)
    }
    /// Modifier to adapt foreground color to existing text
    /// - Parameter color: Color to be specified as foreground color
    /// - Returns: Text view with foreground color adaptation
    public func forgroundColor(_ color: Color) -> Self {
        return .init(header: "\(header)\u{001B}[3\(color.ansi)m", contents: contents, footer: footer)
    }
    /// Modifier to adapt background color to existing text
    /// - Parameter color: Color to be specified as background color
    /// - Returns: Text view with background color adaptation
    public func background(_ color: Color) -> Self {
        return .init(header: "\(header)\u{001B}[4\(color.ansi)m", contents: contents, footer: footer)
    }
    /// Applies a bold font weight to the text.
    /// - Returns: Bold text.
    public func bold() -> Self {
        return .init(header: "\(header)\u{001B}[1m", contents: contents, footer: footer)
    }
    /// Applies a bold font weight to the text.
    /// - Parameter isActive: A Boolean value that indicates whether text has bold styling.
    /// - Returns: Bold text.
    public func bold(_ isActive: Bool) -> Self {
        return .init(header: isActive ? "\(header)\u{001B}[1m" : "\(header)", contents: contents, footer: footer)
    }
    /// Sets the font weight of the text.
    /// - Parameter weight: One of the available font weights.
    /// - Returns: Text view with adapted text weighting
    public func fontWeight(_ weight: Weight) -> Self {
        if weight == .default {
            return .init(header: header, contents: contents, footer: footer)
        } else {
            return .init(header: "\(header)\u{001B}[\(weight.rawValue)m", contents: contents, footer: footer)
        }
    }
    /// Applies italics to the text.
    /// - Returns: Italic text.
    public func italic() -> Self {
        return .init(header: "\(header)\u{001B}[3m", contents: contents, footer: footer)
    }
    /// Applies italics to the text.
    /// - Parameter isActive: A Boolean value that indicates whether italic styling is added.
    /// - Returns: Italic text.
    public func italic(_ isActive: Bool) -> Self {
        return .init(header: isActive ? "\(header)\u{001B}[3m" : "\(header)", contents: contents, footer: footer)
    }
    /// Applies an underline to the text.
    /// - Returns: Text with a line.
    public func underline() -> Self {
        return .init(header: "\(header)\u{001B}[4m", contents: contents, footer: footer)
    }
    /// Applies an underline to the text.
    /// - Parameter isActive: A Boolean value that indicates whether underline styling is added. The default value is true.
    /// - Returns: Text with a line.
    public func underline(_ isActive: Bool) -> Self {
        return .init(header: isActive ? "\(header)\u{001B}[4m" : "\(header)", contents: contents, footer: footer)
    }
    /// Applies a blink to the text.
    /// - Parameter style: Flashing Method
    /// - Returns: Blinking text.
    public func blink(_ style: BlinkStyle) -> Self {
        if style == .none {
            return .init(header: header, contents: contents, footer: footer)
        } else {
            return .init(header: "\(header)\u{001B}[\(style.rawValue)m", contents: contents, footer: footer)
        }
    }
    /// Hides this view unconditionally.
    /// - Returns: A hidden view.
    public func hidden() -> Self {
        return .init(header: "\(header)\u{001B}[8m", contents: contents, footer: footer)
    }
    /// Hides this view unconditionally.
    /// - Parameter isActive: A Boolean value that indicates whether text has hiden.
    /// - Returns: A hidden view.
    public func hidden(_ isActive: Bool) -> Self {
        return .init(header: isActive ? "\(header)\u{001B}[8m" : "\(header)", contents: contents, footer: footer)
    }
    /// Applies a strikethrough to the text.
    /// - Returns: Text with a line through its center.
    public func strikethrough() -> Self {
        return .init(header: "\(header)\u{001B}[9m", contents: contents, footer: footer)
    }
    /// Applies a strikethrough to the text.
    /// - Parameter isActive: A Boolean value that indicates whether the text has a strikethrough applied.
    /// - Returns: Text with a line through its center.
    public func strikethrough(_ isActive: Bool) -> Self {
        return .init(header: isActive ? "\(header)\u{001B}[9m" : "\(header)", contents: contents, footer: footer)
    }
    /// Whether to break the View at the end
    /// - Parameter newLine: whether or not to start a new line
    /// - Returns: Adapted view
    public func newLine(_ newLine: Bool = true) -> Self {
        return .init(header: header, contents: contents, footer: newLine)
    }
}

/// A type that represents part of your CLT’s user interface and provides modifiers that you use to configure views.
public protocol View {
    @ViewBuilder
    /// What the view displays
    var body: [View] { get }
    
    func addHeader(_ header: String) -> Self
    /// Methods for rendering text
    func render()
}

public extension View {
    func addHeader(_ header: String) -> Self {
        return self
    }
    /// Default implementation of the render function
    func render() {
        body.forEach {
            $0.render()
        }
    }
}
