//
//  Emoticon.swift
//
//  
//  Created by Keisuke Chinone on 2024/06/04.
//


/// A customizable ASCII-art emoticon view.
///
/// `Emoticon` renders a three-part face — eyes, optional nose, and mouth —
/// using characters from the ``EyesStyle``, ``NoseStyle``, and ``MouthStyle``
/// enumerations.
///
/// ```swift
/// // Default emoticon: :-)
/// Emoticon().render()
///
/// // Custom combination
/// Emoticon(eye: .caret, nose: .none, mouth: .smile).render()
/// // ^_^
///
/// // With explicit nose
/// Emoticon(eye: .colon, nose: .hyphen, mouth: .smile).render()
/// // :-)
/// ```
///
/// ## Available styles
///
/// | Property | Type | Example values |
/// | -------- | ---- | -------------- |
/// | `eye`    | ``EyesStyle``  | `.colon`, `.semicolon`, `.caret` |
/// | `nose`   | ``NoseStyle``  | `.none`, `.hyphen`, `.o` |
/// | `mouth`  | ``MouthStyle`` | `.smile`, `.frown`, `.open` |
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
    public var body: some View {
        Group(contents: [Text(header: header, content: content)])
    }

    @_spi(RenderingInternals)
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
