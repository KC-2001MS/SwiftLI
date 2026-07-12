//
//  Color.swift
//
//  Created by Keisuke Chinone on 2024/05/28.
//


/// A color value that can be applied to a view's foreground or background.
///
/// Pass a `Color` to ``View/forgroundColor(_:)`` or ``View/background(_:)`` to
/// style a view with ANSI terminal colors. SwiftLI maps each value to the
/// corresponding ANSI SGR (Select Graphic Rendition) color code.
///
/// Like SwiftUI's `Color`, the value is **opaque**: how a color is represented
/// is an implementation detail, so new colors can be added without affecting
/// existing code. Compare colors with `==`; they cannot be switched over.
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
/// ## Semantic and dynamic colors
///
/// Colors can adapt to the terminal's ``ColorScheme``: a dynamic color
/// resolves against the `\.colorScheme` environment value at render time, so
/// the same view reads well on light and dark backgrounds — and follows
/// `.environment(\.colorScheme, ...)` overrides per subtree.
///
/// ```swift
/// Text("Caption").forgroundColor(.secondary)          // scheme-aware grey
/// Text("Warn").forgroundColor(.dynamic(light: .red, dark: .yellow))
/// ```
///
/// The SwiftUI standard palette (``orange``, ``pink``, ``purple``, ``brown``,
/// ``indigo``, ``mint``, ``teal``, ``gray``) is also available, mapped to the
/// closest 256-color palette entries.
///
/// > Note: 256-color and true-color support depends on the terminal emulator.
/// > Standard named colors (`.black` through `.white`) are universally supported.
public struct Color: Equatable, Sendable, CustomStringConvertible {

    /// The private representation — deliberately not exposed, so user code
    /// cannot exhaustively switch over colors and new colors remain
    /// source-compatible additions.
    private indirect enum Storage: Equatable, Sendable {
        /// A named ANSI color: the final digit of the SGR code (`"0"`–`"7"`,
        /// or `"9"` for the terminal default).
        case named(String)
        /// A 256-color palette index.
        case palette(Int)
        /// A 24-bit RGB true color.
        case rgb(Int, Int, Int)
        /// A pair resolved against the current ``ColorScheme`` at render time.
        case dynamic(light: Color, dark: Color)
    }

    private let storage: Storage

    private init(_ storage: Storage) {
        self.storage = storage
    }

    // MARK: - Named colors (ANSI 3-bit / 4-bit palette)

    /// The default ANSI black color (code 0).
    public static let black = Color(.named("0"))

    /// The default ANSI red color (code 1).
    public static let red = Color(.named("1"))

    /// The default ANSI green color (code 2).
    public static let green = Color(.named("2"))

    /// The default ANSI yellow color (code 3).
    public static let yellow = Color(.named("3"))

    /// The default ANSI blue color (code 4).
    public static let blue = Color(.named("4"))

    /// The default ANSI magenta color (code 5).
    public static let magenta = Color(.named("5"))

    /// The default ANSI cyan color (code 6).
    public static let cyan = Color(.named("6"))

    /// The default ANSI white color (code 7).
    public static let white = Color(.named("7"))

    /// The terminal's default foreground or background color.
    ///
    /// Using `.primary` resets the color to whatever the user has configured
    /// as their terminal's default text color.
    public static let primary = Color(.named("9"))

    // MARK: - Palette and true color

    /// A color from the terminal's 256-color palette.
    ///
    /// - Parameter bit: A palette index in the range `0–255`.
    public static func eight_bit(_ bit: Int) -> Color {
        Color(.palette(bit))
    }

    /// A 24-bit RGB true color.
    ///
    /// - Parameters:
    ///   - r: Red component, `0–255`.
    ///   - g: Green component, `0–255`.
    ///   - b: Blue component, `0–255`.
    public static func rgb(r: Int, g: Int, b: Int) -> Color {
        Color(.rgb(r, g, b))
    }

    // MARK: - Semantic and dynamic colors

    /// A color that resolves against the current ``ColorScheme`` at render
    /// time: `light` on a light terminal background, `dark` on a dark one.
    ///
    /// The scheme is read from the `\.colorScheme` environment value, so a
    /// subtree override (`.environment(\.colorScheme, .light)`) changes how
    /// the color resolves inside that subtree.
    ///
    /// ```swift
    /// Text("Warning").forgroundColor(.dynamic(light: .red, dark: .yellow))
    /// ```
    public static func dynamic(light: Color, dark: Color) -> Color {
        Color(.dynamic(light: light, dark: dark))
    }

    /// A secondary, de-emphasised text color that adapts to the color scheme:
    /// a darker grey on light backgrounds, a lighter grey on dark ones.
    public static let secondary = Color.dynamic(light: .eight_bit(240), dark: .eight_bit(245))

    // MARK: - SwiftUI standard palette (closest 256-color entries)

    /// A gray color (256-color palette entry 245).
    public static let gray = Color.eight_bit(245)

    /// An orange color (256-color palette entry 208).
    public static let orange = Color.eight_bit(208)

    /// A pink color (256-color palette entry 205).
    public static let pink = Color.eight_bit(205)

    /// A purple color (256-color palette entry 135).
    public static let purple = Color.eight_bit(135)

    /// A brown color (256-color palette entry 130).
    public static let brown = Color.eight_bit(130)

    /// An indigo color (256-color palette entry 63).
    public static let indigo = Color.eight_bit(63)

    /// A mint color (256-color palette entry 43).
    public static let mint = Color.eight_bit(43)

    /// A teal color (256-color palette entry 38).
    public static let teal = Color.eight_bit(38)

    // MARK: - ANSI lowering

    /// A readable description (`.red`, `.eight_bit(202)`, …), since the
    /// storage itself is private.
    public var description: String {
        switch storage {
        case .named(let code):
            switch code {
            case "0": ".black"
            case "1": ".red"
            case "2": ".green"
            case "3": ".yellow"
            case "4": ".blue"
            case "5": ".magenta"
            case "6": ".cyan"
            case "7": ".white"
            case "9": ".primary"
            default:  ".named(\(code))"
            }
        case .palette(let bit):
            ".eight_bit(\(bit))"
        case .rgb(let r, let g, let b):
            ".rgb(r: \(r), g: \(g), b: \(b))"
        case .dynamic(let light, let dark):
            ".dynamic(light: \(light), dark: \(dark))"
        }
    }

    internal var ansi: String {
        switch storage {
        case .named(let code):
            code
        case .palette(let bit):
            "8;5;\(bit)"
        case .rgb(let r, let g, let b):
            "8;2;\(r);\(g);\(b)"
        case .dynamic(let light, let dark):
            // Resolved at render time, when the view's body is evaluated
            // inside the render pass's environment scope — so a subtree's
            // `.environment(\.colorScheme, ...)` override is honoured.
            (EnvironmentStack.current.colorScheme == .dark ? dark : light).ansi
        }
    }

    /// Flattens any `.dynamic` layer to a concrete color for the given scheme.
    /// Non-dynamic colors are returned unchanged.
    internal func resolved(scheme: ColorScheme) -> Color {
        switch storage {
        case .dynamic(let light, let dark):
            scheme == .dark ? dark : light
        default:
            self
        }
    }
}
