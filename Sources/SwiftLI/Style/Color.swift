//
//  Color.swift
//
//  
//  Created by Keisuke Chinone on 2024/05/28.
//


/// A representation of a color that adapts to a given context.
public enum Color: Sendable {
    
    case black
    case red
    case green
    case yellow
    case blue
    case magenta
    case cyan
    case white
    case eight_bit(_ bit: Int)
//    Commented out because it is not supported by the standard terminal of macOS
//    case rgb(r:Int,g:Int,b:Int)
    case primary
    
    internal var ansi: String {
        switch self {
        case .black:
            "0"
        case .red:
            "1"
        case .green:
            "2"
        case .yellow:
            "3"
        case .blue:
            "4"
        case .magenta:
            "5"
        case .cyan:
            "6"
        case .white:
            "7"
        case .eight_bit(let bit):
            "8;5;\(bit)"
//    Removed because it does not work with macOS terminal app
//        case .rgb(let r, let g, let b):
//            "8;2;\(r);\(g);\(b)"
        case .primary:
            "9"
        }
    }
}
