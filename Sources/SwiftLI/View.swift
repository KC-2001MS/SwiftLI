//
//  View.swift
//
//
//  Created by Keisuke Chinone on 2024/05/27.
//


/// View to display text in terminal
public struct Text: View {
    /// Hetter to specify display style
    private var header: String
    
    /// String to display
    private let string: String
    
    /// Creates a text view that is displayed in the terminal.
    /// - Parameter string: String to be displayed in the terminal
    public init(_ string: String) {
        self.header = ""
        self.string = string
    }
    
    public init(repeating: String, count: Int) {
        self.header = ""
        self.string = String(repeating: repeating, count: count)
    }
    
    init(header: String,repeating: String, count: Int) {
        self.header = header
        self.string = String(repeating: repeating, count: count)
    }
    /// Initializer to realize method chain
    /// - Parameters:
    ///   - header: Hetter to specify display style
    ///   - string: String to display
    private init(header: String,_ string: String) {
        self.header = "\(header)"
        self.string = string
    }
    /// What the view displays
    public var body: [any View] {
        return []
    }
    /// Methods for rendering text
    public func render() {
        print("\(header)\(string)\u{001B}[0m", terminator: "")
    }
    /// Modifier to adapt foreground color to existing text
    /// - Parameter color: Color to be specified as foreground color
    /// - Returns: Text view with foreground color adaptation
    public func forgroundColor(_ color: Color) -> Text {
        return Text(header: "\(header)\u{001B}[3\(color.name)m", string)
    }
    /// Modifier to adapt background color to existing text
    /// - Parameter color: Color to be specified as background color
    /// - Returns: Text view with background color adaptation
    public func background(_ color: Color) -> Text {
        return Text(header: "\(header)\u{001B}[4\(color.name)m", string)
    }
    /// Applies a bold font weight to the text.
    /// - Returns: Bold text.
    public func bold() -> Text {
        return Text(header: "\(header)\u{001B}[1m", string)
    }
    /// Applies a bold font weight to the text.
    /// - Parameter isActive: A Boolean value that indicates whether text has bold styling.
    /// - Returns: Bold text.
    public func bold(_ isActive: Bool) -> Text {
        return Text(header: isActive ? "\(header)\u{001B}[1m" : "\(header)", string)
    }
    /// Sets the font weight of the text.
    /// - Parameter weight: One of the available font weights.
    /// - Returns: Text view with adapted text weighting
    public func fontWeight(_ weight: Weight) -> Text {
        if weight == .default {
            return Text(header: header, string)
        } else {
            return Text(header: "\(header)\u{001B}[\(weight.rawValue)m", string)
        }
    }
    /// Applies italics to the text.
    /// - Returns: Italic text.
    public func italic() -> Text {
        return Text(header: "\(header)\u{001B}[3m", string)
    }
    /// Applies italics to the text.
    /// - Parameter isActive: A Boolean value that indicates whether italic styling is added.
    /// - Returns: Italic text.
    public func italic(_ isActive: Bool) -> Text {
        return Text(header: isActive ? "\(header)\u{001B}[3m" : "\(header)", string)
    }
    /// Applies an underline to the text.
    /// - Returns: Text with a line.
    public func underline() -> Text {
        return Text(header: "\(header)\u{001B}[4m", string)
    }
    /// Applies an underline to the text.
    /// - Parameter isActive: A Boolean value that indicates whether underline styling is added. The default value is true.
    /// - Returns: Text with a line.
    public func underline(_ isActive: Bool) -> Text {
        return Text(header: isActive ? "\(header)\u{001B}[4m" : "\(header)", string)
    }
    /// Applies a blink to the text.
    /// - Parameter style: Flashing Method
    /// - Returns: Blinking text.
    public func blink(_ style: BlinkStyle) -> Text {
        if style == .none {
            return Text(header: header, string)
        } else {
            return Text(header: "\(header)\u{001B}[\(style.rawValue)m", string)
        }
    }
    /// Hides this view unconditionally.
    /// - Returns: A hidden view.
    public func hidden() -> Text {
        return Text(header: "\(header)\u{001B}[8m", string)
    }
    /// Hides this view unconditionally.
    /// - Parameter isActive: A Boolean value that indicates whether text has hiden.
    /// - Returns: A hidden view.
    public func hidden(_ isActive: Bool) -> Text {
        return Text(header: isActive ? "\(header)\u{001B}[8m" : "\(header)", string)
    }
    /// Applies a strikethrough to the text.
    /// - Returns: Text with a line through its center.
    public func strikethrough() -> Text {
        return Text(header: "\(header)\u{001B}[9m", string)
    }
    /// Applies a strikethrough to the text.
    /// - Parameter isActive: A Boolean value that indicates whether the text has a strikethrough applied.
    /// - Returns: Text with a line through its center.
    public func strikethrough(_ isActive: Bool) -> Text {
        return Text(header: isActive ? "\(header)\u{001B}[9m" : "\(header)", string)
    }
}

/// A type that represents part of your CLT’s user interface and provides modifiers that you use to configure views.
public protocol View {
    @ViewBuilder
    var body: [View] { get }
    
    /// Methods for rendering text
    func render()
}

public extension View {
    func render() {
        body.forEach { $0.render() }
    }
}

extension View {
    func propagate(string: String) -> Self {
        return self
    }
}
