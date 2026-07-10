//
//  BorderStyle.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/08.
//


/// The visual style of a box drawn by ``View/border(_:color:)``.
///
/// Each style is a table of the six Unicode box-drawing glyphs used to draw a
/// rectangle: the four corners plus the horizontal and vertical edges. The
/// terminal renders these as ordinary characters, so a border needs no special
/// graphics support — it works even in the macOS Terminal.
///
/// ```swift
/// Text("Rounded")
///     .padding()
///     .border(.rounded)
/// ```
public enum BorderStyle: CaseIterable, Sendable {

    /// Rounded corners using the arc glyphs `╭ ╮ ╰ ╯` with light edges.
    case rounded

    /// Square corners using the light glyphs `┌ ┐ └ ┘`.
    case single

    /// Square corners using the double-line glyphs `╔ ╗ ╚ ╝`.
    case double

    /// Square corners using the heavy glyphs `┏ ┓ ┗ ┛`.
    case heavy

    /// The corner and edge glyphs that draw this style's box.
    var glyphs: (topLeft: Character, topRight: Character, bottomLeft: Character, bottomRight: Character, horizontal: Character, vertical: Character) {
        switch self {
        case .rounded: return ("╭", "╮", "╰", "╯", "─", "│")
        case .single:  return ("┌", "┐", "└", "┘", "─", "│")
        case .double:  return ("╔", "╗", "╚", "╝", "═", "║")
        case .heavy:   return ("┏", "┓", "┗", "┛", "━", "┃")
        }
    }
}
