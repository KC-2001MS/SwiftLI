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
public struct Emoticon: View, Sendable, Equatable {
    let header: String
    
    let content: String
    
    /// Default Emoticon View
    public init() {
        self.header = ""
        self.content = "\(EyesStyle.default.rawValue)\(NoseStyle.none.rawValue)\(MouthStyle.default.rawValue)"
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
    }
    
    init(
        header: String,
        content: String
    ) {
        self.header = header
        self.content = content
    }
    /// What the view displays
    public var body: [View] {
        Text(header: header, content: content)
    }

    public func addHeader(_ header: String) -> Self {
        .init(header: header + self.header, content: content)
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
