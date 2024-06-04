//
//  Emoticon.swift
//
//  
//  Created by Keisuke Chinone on 2024/06/04.
//


public struct Emoticon: View {
    let string: String
    
    init() {
        self.string = "\(EyesStyle.default.rawValue)\(NoseStyle.none.rawValue)\(MouthStyle.default.rawValue)"
    }
    
    init(eye: EyesStyle, nose: NoseStyle, mouth: MouthStyle) {
        self.string = "\(eye.rawValue)\(nose.rawValue)\(mouth.rawValue)"
    }
    
    init(eye: EyesStyle,mouth: MouthStyle) {
        self.string = "\(eye.rawValue)\(mouth.rawValue)"
    }
    
    /// What the view displays
    public var body: [View] {
        Text(string)
    }
}

enum EyesStyle: String {
    case `default` = ":"
    case open = "="
    case wideOpen = "8"
    case teary = ":'"
    case x = "X"
}

enum NoseStyle: String {
    case none = ""
    case standard = "‑"
    case high = "^"
}

enum MouthStyle: String {
    case `default` = ")"
    case open = "D"
    case turnedUp = ">"
    case turnedDown = "<"
    case hold = "("
}
