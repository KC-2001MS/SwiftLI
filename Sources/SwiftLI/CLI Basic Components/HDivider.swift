//
//  HDivider.swift
//
//  
//  Created by Keisuke Chinone on 2024/05/28.
//


/// View to display horizontal dividers
///
/// Horizontal partitions can be added.
/// ```swift
/// let hdivider = HDivider(10)
/// hdivider.render()
/// ```
/// Modifiers can be added to change the style.
public struct HDivider: View {
    let header: String
    
    let character: Character
    
    let count: Int
    
    let footer: Bool
    
    /// Creates a space view that is displayed in the terminal.
    /// - Parameter count: Space Width
    public init(_ count: Int) {
        self.header = ""
        self.character = "-"
        self.count = count
        self.footer = false
    }
    
    init(
        header: String,
        character: Character,
        count: Int,
        footer: Bool
    ) {
        self.header = header
        self.character = character
        self.count = count
        self.footer = footer
    }
    /// What the view displays
    public var body: [View] {
        Text(header: self.header,repeating: self.character, count: self.count, footer: self.footer)
    }
    
    public func addHeader(_ header: String) -> Self {
        return HDivider(header: header + self.header,character: self.character, count: self.count, footer: self.footer)
    }
    /// Specifies the line type of the Divider
    /// - Parameter style: Type of line used as divider
    /// - Returns: Divider view of the specified line type
    public func lineStyle(_ style: LineStyle) -> HDivider {
        switch style {
        case .default:
            return .init(header: self.header, character: "-", count: self.count,footer:  self.footer)
        case .double_line:
            return .init(header: self.header, character: "=", count: self.count,footer:  self.footer)
        }
    }
    /// Modifier to adapt foreground color to existing text
    /// - Parameter color: Color to be specified as foreground color
    /// - Returns: Divider view with foreground color adaptation
    public func forgroundColor(_ color: Color) -> HDivider {
        return .init(header: "\(header)\u{001B}[3\(color.ansi)m", character: character, count: count,footer: footer)
    }
    /// Modifier to adapt background color to existing text
    /// - Parameter color: Color to be specified as background color
    /// - Returns: Divider view with background color adaptation
    public func background(_ color: Color) -> HDivider {
        return .init(header: "\(header)\u{001B}[4\(color.ansi)m", character: character, count: count,footer: footer)
    }
    /// Applies a bold font weight to the text.
    /// - Returns: Bold text.
    public func bold() -> HDivider {
        return .init(header: "\(header)\u{001B}[1m", character: character, count: count,footer: footer)
    }
    /// Applies a bold font weight to the text.
    /// - Parameter isActive: A Boolean value that indicates whether text has bold styling.
    /// - Returns: Bold text.
    public func bold(_ isActive: Bool) -> HDivider {
        return .init(header: isActive ? "\(header)\u{001B}[1m" : "\(header)", character: character, count: count,footer: footer)
    }
    /// Sets the font weight of the text.
    /// - Parameter weight: One of the available font weights.
    /// - Returns: Divider view with adapted text weighting
    public func fontWeight(_ weight: Weight) -> HDivider {
        if weight == .default {
            return .init(header: header, character: character, count: count,footer: footer)
        } else {
            return .init(header: "\(header)\u{001B}[\(weight.rawValue)m", character: character, count: count,footer: footer)
        }
    }
    /// Applies a blink to the text.
    /// - Parameter style: Flashing Method
    /// - Returns: Blinking text.
    public func blink(_ style: BlinkStyle) -> HDivider {
        if style == .none {
            return .init(header: header, character: character, count: count,footer: footer)
        } else {
            return .init(header: "\(header)\u{001B}[\(style.rawValue)m", character: character, count: count,footer: footer)
        }
    }
    /// Hides this view unconditionally.
    /// - Returns: A hidden view.
    public func hidden() -> HDivider {
        return .init(header: "\(header)\u{001B}[8m", character: character, count: count,footer: footer)
    }
    /// Hides this view unconditionally.
    /// - Parameter isActive: A Boolean value that indicates whether text has hiden.
    /// - Returns: A hidden view.
    public func hidden(_ isActive: Bool) -> HDivider {
        return .init(header: isActive ? "\(header)\u{001B}[8m" : "\(header)", character: character, count: count,footer: footer)
    }
    /// Whether to break the View at the end
    /// - Parameter newLine: whether or not to start a new line
    /// - Returns: Adapted view
    public func newLine(_ newLine: Bool = true) -> HDivider {
        return .init(header: header,character: character,count: count , footer: newLine)
    }
}
