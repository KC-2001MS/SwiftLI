//
//  Emoticon.swift
//
//  
//  Created by Keisuke Chinone on 2024/06/04.
//


public struct Emoticon: View {
    let string: String
    
    let header: String
    /// Default Emoticon View
    public init() {
        self.string = "\(EyesStyle.default.rawValue)\(NoseStyle.none.rawValue)\(MouthStyle.default.rawValue)"
        self.header = ""
    }
    /// Emoticon View initializer consisting of eyes, nose and mouth
    /// - Parameters:
    ///   - eye: eye shape
    ///   - nose: nose shape
    ///   - mouth: shape of the mouth
    public init(eye: EyesStyle, nose: NoseStyle, mouth: MouthStyle) {
        self.string = "\(eye.rawValue)\(nose.rawValue)\(mouth.rawValue)"
        self.header = ""
    }
    /// Emoticon View initializer consisting of eyes and mouth
    /// - Parameters:
    ///   - eye: eye shape
    ///   - mouth: shape of the mouth
    public init(eye: EyesStyle,mouth: MouthStyle) {
        self.string = "\(eye.rawValue)\(mouth.rawValue)"
        self.header = ""
    }
    
    private init(header: String, string: String) {
        self.header = header
        self.string = string
    }
    /// What the view displays
    public var body: [View] {
        Text(header: header, string)
    }
    /// Modifier to adapt foreground color to existing text
    /// - Parameter color: Color to be specified as foreground color
    /// - Returns: Divider view with foreground color adaptation
    public func forgroundColor(_ color: Color) -> Emoticon {
        return .init(header: "\(header)\u{001B}[3\(color.ansi)m", string: string)
    }
    /// Modifier to adapt background color to existing text
    /// - Parameter color: Color to be specified as background color
    /// - Returns: Divider view with background color adaptation
    public func background(_ color: Color) -> Emoticon {
        return .init(header: "\(header)\u{001B}[4\(color.ansi)m", string: string)
    }
    /// Applies a bold font weight to the text.
    /// - Returns: Bold text.
    public func bold() -> Emoticon {
        return .init(header: "\(header)\u{001B}[1m", string: string)
    }
    /// Applies a bold font weight to the text.
    /// - Parameter isActive: A Boolean value that indicates whether text has bold styling.
    /// - Returns: Bold text.
    public func bold(_ isActive: Bool) -> Emoticon {
        return .init(header: isActive ? "\(header)\u{001B}[1m" : "\(header)", string: string)
    }
    /// Sets the font weight of the text.
    /// - Parameter weight: One of the available font weights.
    /// - Returns: Divider view with adapted text weighting
    public func fontWeight(_ weight: Weight) -> Emoticon {
        if weight == .default {
            return .init(header: header, string: string)
        } else {
            return .init(header: "\(header)\u{001B}[\(weight.rawValue)m", string: string)
        }
    }
    /// Applies a blink to the text.
    /// - Parameter style: Flashing Method
    /// - Returns: Blinking text.
    public func blink(_ style: BlinkStyle) -> Emoticon {
        if style == .none {
            return .init(header: header, string: string)
        } else {
            return .init(header: "\(header)\u{001B}[\(style.rawValue)m", string: string)
        }
    }
    /// Hides this view unconditionally.
    /// - Returns: A hidden view.
    public func hidden() -> Emoticon {
        return .init(header: "\(header)\u{001B}[8m", string: string)
    }
    /// Hides this view unconditionally.
    /// - Parameter isActive: A Boolean value that indicates whether text has hiden.
    /// - Returns: A hidden view.
    public func hidden(_ isActive: Bool) -> Emoticon {
        return .init(header: isActive ? "\(header)\u{001B}[8m" : "\(header)", string: string)
    }
}
/// Specify the Emoticon eye text
public enum EyesStyle: String {
    case `default` = ":"
    case open = "="
    case wideOpen = "8"
    case teary = ":'"
    case x = "X"
}
/// Specify the Emoticon nose text
public enum NoseStyle: String {
    case none = ""
    case standard = "‑"
    case high = "^"
}
/// Specify the Emoticon mouth text
public enum MouthStyle: String {
    case `default` = ")"
    case open = "D"
    case turnedUp = ">"
    case turnedDown = "<"
    case hold = "("
}
