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
    let style: TextStyle

    let content: String

    /// Default Emoticon View
    public init() {
        self.style = .plain
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
        self.style = .plain
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
        self.style = .plain
        self.content = "\(eye.rawValue)\(mouth.rawValue)"
    }

    init(
        style: TextStyle,
        content: String
    ) {
        self.style = style
        self.content = content
    }
    /// What the view displays
    public var body: some View {
        Text(style: style, content: content)
    }

    @_spi(RenderingInternals)
    public func applyingStyle(_ style: TextStyle) -> Self {
        .init(style: self.style.inheriting(style), content: content)
    }
}
/// Specify the Emoticon eye text
public enum EyesStyle: String, CaseIterable {
    /// Standard colon eyes `:`
    case `default` = ":"
    /// Wide-open eyes `=`
    case open = "="
    /// Very wide-open eyes `8`
    case wideOpen = "8"
    /// Teary eyes `:'`
    case teary = ":'"
    /// Crossed-out eyes `X`
    case x = "X"
}
/// Specify the Emoticon nose text
public enum NoseStyle: String, CaseIterable {
    /// No nose character
    case none = ""
    /// Standard hyphen nose `‑`
    case standard = "‑"
    /// Caret nose `^`
    case high = "^"
}
/// Specify the Emoticon mouth text
public enum MouthStyle: String, CaseIterable {
    /// Standard smile mouth `)`
    case `default` = ")"
    /// Open/grinning mouth `D`
    case open = "D"
    /// Mouth turned up `>`
    case turnedUp = ">"
    /// Mouth turned down `<`
    case turnedDown = "<"
    /// Flat/holding mouth `(`
    case hold = "("
}
