//
//  HDivider.swift
//
//  
//  Created by Keisuke Chinone on 2024/05/28.
//


/// View to display horizontal dividers
public struct HDivider: View {
    private let count: Int
    
    private var string: String
    
    private var header: String
    /// Creates a space view that is displayed in the terminal.
    /// - Parameter count: Space Width
    public init(_ count: Int) {
        self.count = count
        self.string = "-"
        self.header = ""
    }
    
    private init(header: String,string: String,count: Int) {
        self.count = count
        self.string = string
        self.header = header
    }
    /// What the view displays
    public var body: [View] {
        Text(header: header,repeating: string, count: count)
    }
    /// Specifies the line type of the Divider
    /// - Parameter style: Type of line used as divider
    /// - Returns: Divider view of the specified line type
    public func lineStyle(_ style: LineStyle) -> HDivider {
        switch style {
        case .default:
            return .init(header: self.header, string: "-", count: self.count)
        case .double_line:
            return .init(header: self.header, string: "=", count: self.count)
        }
    }
    /// Modifier to adapt foreground color to existing text
    /// - Parameter color: Color to be specified as foreground color
    /// - Returns: Divider view with foreground color adaptation
    public func forgroundColor(_ color: Color) -> HDivider {
        return .init(header: "\(header)\u{001B}[3\(color.ansi)m", string: string, count: count)
    }
    /// Modifier to adapt background color to existing text
    /// - Parameter color: Color to be specified as background color
    /// - Returns: Divider view with background color adaptation
    public func background(_ color: Color) -> HDivider {
        return .init(header: "\(header)\u{001B}[4\(color.ansi)m", string: string, count: count)
    }
    /// Applies a bold font weight to the text.
    /// - Returns: Bold text.
    public func bold() -> HDivider {
        return .init(header: "\(header)\u{001B}[1m", string: string, count: count)
    }
    /// Applies a bold font weight to the text.
    /// - Parameter isActive: A Boolean value that indicates whether text has bold styling.
    /// - Returns: Bold text.
    public func bold(_ isActive: Bool) -> HDivider {
        return .init(header: isActive ? "\(header)\u{001B}[1m" : "\(header)", string: string, count: count)
    }
    /// Sets the font weight of the text.
    /// - Parameter weight: One of the available font weights.
    /// - Returns: Divider view with adapted text weighting
    public func fontWeight(_ weight: Weight) -> HDivider {
        if weight == .default {
            return .init(header: header, string: string, count: count)
        } else {
            return .init(header: "\(header)\u{001B}[\(weight.rawValue)m", string: string, count: count)
        }
    }
    /// Applies a blink to the text.
    /// - Parameter style: Flashing Method
    /// - Returns: Blinking text.
    public func blink(_ style: BlinkStyle) -> HDivider {
        if style == .none {
            return .init(header: header, string: string, count: count)
        } else {
            return .init(header: "\(header)\u{001B}[\(style.rawValue)m", string: string, count: count)
        }
    }
    /// Hides this view unconditionally.
    /// - Returns: A hidden view.
    public func hidden() -> HDivider {
        return .init(header: "\(header)\u{001B}[8m", string: string, count: count)
    }
    /// Hides this view unconditionally.
    /// - Parameter isActive: A Boolean value that indicates whether text has hiden.
    /// - Returns: A hidden view.
    public func hidden(_ isActive: Bool) -> HDivider {
        return .init(header: isActive ? "\(header)\u{001B}[8m" : "\(header)", string: string, count: count)
    }
}
/// Specify the line type of the Divider
public enum LineStyle {
    case `default`
    case double_line
}
