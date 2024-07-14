//
//  Emoticon.swift
//
//  
//  Created by Keisuke Chinone on 2024/06/04.
//


/// Structure to build a view of emoticons
///
/// This structure allows for easy construction of emoticons used in English-speaking countries.
///
/// You can create default emoticons with the init() initializer:)
/// ```swift
/// let emoticon = Emoticon()
/// emoticon.render()
/// ```
/// init(eye: EyesStyle,nose: NoseStyle,mouth: MouthStyle)Initializers can be used to create a variety of emoticons.
/// ```swift
/// let emoticon = Emoticon(nose: .wideOpen, nose .standard, mouth: .turnedUp)
/// emoticon.render()
/// ```
/// Modifiers can be added to change the style.
public struct Emoticon: View {
    let header: String
    
    let content: String
    
    let footer: Bool
    /// Default Emoticon View
    public init() {
        self.header = ""
        self.content = "\(EyesStyle.default.rawValue)\(NoseStyle.none.rawValue)\(MouthStyle.default.rawValue)"
        self.footer = false
    }
    /// Emoticon View initializer consisting of eyes, nose and mouth
    /// - Parameters:
    ///   - eye: eye shape
    ///   - nose: nose shape
    ///   - mouth: shape of the mouth
    public init(
        eye: EyesStyle,
        nose: NoseStyle,
        mouth: MouthStyle
    ) {
        self.header = ""
        self.content = "\(eye.rawValue)\(nose.rawValue)\(mouth.rawValue)"
        self.footer = false
    }
    /// Emoticon View initializer consisting of eyes and mouth
    /// - Parameters:
    ///   - eye: eye shape
    ///   - mouth: shape of the mouth
    public init(
        eye: EyesStyle,
        mouth: MouthStyle
    ) {
        self.header = ""
        self.content = "\(eye.rawValue)\(mouth.rawValue)"
        self.footer = false
    }
    
    init(
        header: String,
        content: String,
        footer: Bool = false
    ) {
        self.header = header
        self.content = content
        self.footer = footer
    }
    /// What the view displays
    public var body: [View] {
        Text(header: header,content: content)
    }
    /// Modifier to adapt foreground color to existing text
    /// - Parameter color: Color to be specified as foreground color
    /// - Returns: Divider view with foreground color adaptation
    public func forgroundColor(_ color: Color) -> Emoticon {
        return .init(header: "\(header)\u{001B}[3\(color.ansi)m", content: content)
    }
    /// Modifier to adapt background color to existing text
    /// - Parameter color: Color to be specified as background color
    /// - Returns: Divider view with background color adaptation
    public func background(_ color: Color) -> Emoticon {
        return .init(header: "\(header)\u{001B}[4\(color.ansi)m", content: content)
    }
    /// Applies a bold font weight to the text.
    /// - Returns: Bold text.
    public func bold() -> Emoticon {
        return .init(header: "\(header)\u{001B}[1m", content: content)
    }
    /// Applies a bold font weight to the text.
    /// - Parameter isActive: A Boolean value that indicates whether text has bold styling.
    /// - Returns: Bold text.
    public func bold(_ isActive: Bool) -> Emoticon {
        return .init(header: isActive ? "\(header)\u{001B}[1m" : "\(header)", content: content)
    }
    /// Sets the font weight of the text.
    /// - Parameter weight: One of the available font weights.
    /// - Returns: Divider view with adapted text weighting
    public func fontWeight(_ weight: Weight) -> Emoticon {
        if weight == .default {
            return .init(header: header, content: content)
        } else {
            return .init(header: "\(header)\u{001B}[\(weight.rawValue)m", content: content)
        }
    }
    /// Applies a blink to the text.
    /// - Parameter style: Flashing Method
    /// - Returns: Blinking text.
    public func blink(_ style: BlinkStyle) -> Emoticon {
        if style == .none {
            return .init(header: header, content: content)
        } else {
            return .init(header: "\(header)\u{001B}[\(style.rawValue)m", content: content)
        }
    }
    /// Hides this view unconditionally.
    /// - Returns: A hidden view.
    public func hidden() -> Emoticon {
        return .init(header: "\(header)\u{001B}[8m", content: content)
    }
    /// Hides this view unconditionally.
    /// - Parameter isActive: A Boolean value that indicates whether text has hiden.
    /// - Returns: A hidden view.
    public func hidden(_ isActive: Bool) -> Emoticon {
        return .init(header: isActive ? "\(header)\u{001B}[8m" : "\(header)", content: content)
    }
    /// Whether to break the View at the end
    /// - Parameter newLine: whether or not to start a new line
    /// - Returns: Adapted view
    public func newLine(_ newLine: Bool = true) -> Emoticon {
        return .init(header: header, content: content, footer: newLine)
    }
}
/// Specify the Emoticon eye text
public enum EyesStyle: String, CaseIterable {
    case `default` = ":"
    case open = "="
    case wideOpen = "8"
    case teary = ":'"
    case x = "X"
}
/// Specify the Emoticon nose text
public enum NoseStyle: String, CaseIterable {
    case none = ""
    case standard = "‑"
    case high = "^"
}
/// Specify the Emoticon mouth text
public enum MouthStyle: String, CaseIterable {
    case `default` = ")"
    case open = "D"
    case turnedUp = ">"
    case turnedDown = "<"
    case hold = "("
}
