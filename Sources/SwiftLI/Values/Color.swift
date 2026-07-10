//
//  Color.swift
//
//  Created by Keisuke Chinone on 2024/05/28.
//


/// A color value that can be applied to a view's foreground or background.
///
/// Pass a `Color` to ``View/forgroundColor(_:)`` or ``View/background(_:)`` to
/// style a view with ANSI terminal colors. SwiftLI maps each case to the
/// corresponding ANSI SGR (Select Graphic Rendition) color code.
///
/// ## Named colors (ANSI 3-bit / 4-bit palette)
///
/// ```swift
/// Text("Error").forgroundColor(.red).render()
/// Text("Success").forgroundColor(.green).render()
/// Text("Info").forgroundColor(.cyan).render()
/// ```
///
/// ## 256-color palette
///
/// ```swift
/// // Orange from the 256-color palette (index 202)
/// Text("Orange").forgroundColor(.eight_bit(202)).render()
/// ```
///
/// ## True color (24-bit RGB)
///
/// ```swift
/// Text("Custom").forgroundColor(.rgb(r: 255, g: 165, b: 0)).render()
/// ```
///
/// > Note: 256-color and true-color support depends on the terminal emulator.
/// > Standard named colors (`.black` through `.white`) are universally supported.
public enum Color: Sendable {

    /// The default ANSI black color (code 0).
    case black

    /// The default ANSI red color (code 1).
    case red

    /// The default ANSI green color (code 2).
    case green

    /// The default ANSI yellow color (code 3).
    case yellow

    /// The default ANSI blue color (code 4).
    case blue

    /// The default ANSI magenta color (code 5).
    case magenta

    /// The default ANSI cyan color (code 6).
    case cyan

    /// The default ANSI white color (code 7).
    case white

    /// A color from the terminal's 256-color palette.
    ///
    /// - Parameter bit: A palette index in the range `0–255`.
    case eight_bit(_ bit: Int)

    /// A 24-bit RGB true color.
    ///
    /// - Parameters:
    ///   - r: Red component, `0–255`.
    ///   - g: Green component, `0–255`.
    ///   - b: Blue component, `0–255`.
    case rgb(r: Int, g: Int, b: Int)

    /// The terminal's default foreground or background color.
    ///
    /// Using `.primary` resets the color to whatever the user has configured
    /// as their terminal's default text color.
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
        case .rgb(let r, let g, let b):
            "8;2;\(r);\(g);\(b)"
        case .primary:
            "9"
        }
    }
}
