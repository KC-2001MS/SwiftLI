//
//  View.swift
//
//
//  Created by Keisuke Chinone on 2024/05/27.
//

import Foundation


/// A single-line or multi-line text view that renders styled content to the terminal.
///
/// `Text` is the fundamental building block of SwiftLI layouts. It displays a
/// plain string or a repeated character with optional ANSI styling applied via
/// modifier methods such as ``forgroundColor(_:)``, ``bold()``, or ``italic()``.
///
/// ## Creating a text view
///
/// ```swift
/// // Display a plain string
/// Text("Hello, SwiftLI!").render()
///
/// // Display a repeated character
/// Text(repeating: "-", count: 20).render()
///
/// // Display with styling
/// Text("Hello, SwiftLI!")
///     .forgroundColor(.red)
///     .bold()
///     .render()
/// ```
///
/// ## Localization
///
/// Pass a `LocalizedStringKey` to take advantage of Foundation's localization
/// pipeline. Use ``init(verbatim:)`` when you explicitly want to skip
/// localization.
///
/// ```swift
/// Text("greeting_key")           // looks up "greeting_key" in the strings table
/// Text(verbatim: "Hello!")       // always renders "Hello!" as-is
/// ```
public struct Text: View, Sendable, Equatable {
    let header: String

    let contents: Array<String>

    /// Creates a localized text view.
    ///
    /// The string is resolved through Foundation's `String(localized:)` API using
    /// the bundle and table you specify.
    ///
    /// - Parameters:
    ///   - key: The localization key.
    ///   - tableName: The `.strings` table name, or `nil` for the default table.
    ///   - bundle: The bundle containing the strings file, or `nil` for the main bundle.
    ///   - comment: A hint for translators, or `nil` to omit.
    public init(
        _ key: LocalizedStringKey,
        tableName: String? = nil,
        bundle: Bundle? = nil,
        comment: StaticString? = nil
    ) {
        self.header = ""
        self.contents = [String(localized: key.localizationValue, table: tableName, bundle: bundle, comment: comment)]
    }

    /// Creates a text view that displays a string exactly as given, without localization.
    ///
    /// - Parameter content: The string to display verbatim.
    public init(verbatim content: String) {
        self.header = ""
        self.contents = [content]
    }

    /// Creates a text view from any `StringProtocol` value.
    ///
    /// - Parameter content: A string-like value to display.
    public init<S>(_ content: S) where S : StringProtocol {
        self.header = ""
        self.contents = [String(content)]
    }

    /// Creates a text view that repeats a single character.
    ///
    /// Useful for drawing rules or decorative separators:
    ///
    /// ```swift
    /// Text(repeating: "─", count: 40).render()
    /// ```
    ///
    /// - Parameters:
    ///   - repeating: The character to repeat.
    ///   - count: The number of repetitions.
    public init(
        repeating: Character,
        count: Int
    ) {
        self.header = ""
        self.contents = [String(repeating: repeating, count: count)]
    }

    init(
        header: String,
        repeating: Character,
        count: Int
    ) {
        self.header = header
        self.contents = [String(repeating: repeating, count: count)]
    }

    init(
        header: String,
        contents: Array<String>
    ) {
        self.header = "\(header)"
        self.contents = contents
    }

    init(
        header: String = "",
        content: String
    ) {
        self.header = "\(header)"
        self.contents = [content]
    }

    public var body: some View {
        Group(contents: [])
    }

    @_spi(RenderingInternals)
    public func addHeader(_ header: String) -> Self {
        return Text(header: header + self.header, contents: contents)
    }

    /// Renders the text directly to standard output.
    ///
    /// Writes the styled string to `stdout` without appending a newline.
    /// Call ``render()`` on a top-level view to produce terminal output.
    ///
    /// ```swift
    /// Text("Done!").forgroundColor(.green).bold().render()
    /// ```
    public func render() {
        for content in contents {
            print("\(header)\(content)\u{001B}[0m", terminator: "")
        }
    }

    @_spi(RenderingInternals)
    public func renderString() -> String {
        var s = ""
        for content in contents {
            s += "\(header)\(content)\u{001B}[0m"
        }
        return s
    }

    @_spi(RenderingInternals)
    public func measure() -> Size {
        let s = renderString()
        return _size(of: s.isEmpty ? " " : s)
    }

    @_spi(RenderingInternals)
    public func draw(into canvas: TerminalCanvas, at origin: Point) {
        let s = renderString()
        if s.isEmpty { return }
        canvas.expand(toFit: Rect(origin: origin, size: _size(of: s)))
        canvas.write(s, at: origin)
    }

    static func +(left: Self, right: Self) -> Self {
        let leftContents = left.contents.map({ left.header + $0 })
        let rightContents = right.contents.map({ right.header + $0 })
        return Text(header: "", contents: leftContents + rightContents)
    }
}

/// A type that describes part of a terminal user interface.
///
/// Conform to `View` to build reusable UI components for command-line tools.
/// A `View` defines its content via the ``body`` property, which is composed
/// from other views using ``ViewBuilder`` syntax.
///
/// ## Minimal example
///
/// ```swift
/// struct Greeting: View {
///     var body: some View {
///         Text("Hello, SwiftLI!").bold()
///     }
/// }
///
/// Greeting().render()
/// ```
///
/// ## Rendering
///
/// Call ``render()`` on the root view to write output to `stdout`. All other
/// rendering primitives (`renderString()`, `measure()`, `draw(into:at:)`) are
/// internal implementation details used by the layout system.
///
/// ## Styling
///
/// Apply ANSI styles through the modifier methods declared in the `View`
/// extension: ``forgroundColor(_:)``, ``bold()``, ``italic()``, ``underline()``,
/// ``blink(_:)``, ``hidden()``, and ``strikethrough()``.
public protocol View {
    /// The type of view representing the body of this view.
    associatedtype Body: View

    /// The content and behaviour of this view.
    ///
    /// Implement `body` using ``ViewBuilder`` syntax to compose child views:
    ///
    /// ```swift
    /// var body: some View {
    ///     VStack {
    ///         Text("Title").bold()
    ///         Text("Subtitle").forgroundColor(.cyan)
    ///     }
    /// }
    /// ```
    @ViewBuilder
    var body: Body { get }

    /// Renders the view to standard output without a trailing newline.
    ///
    /// Call this on the root view of your layout to produce terminal output.
    /// For composed layouts, prefer ``HStack``, ``VStack``, or ``Group`` as
    /// the root and call `render()` on the container.
    func render()

    // MARK: - SPI: rendering infrastructure (not part of the public API)

    @_spi(RenderingInternals)
    func addHeader(_ header: String) -> Self

    @_spi(RenderingInternals)
    func renderString() -> String

    @_spi(RenderingInternals)
    func measure() -> Size

    @_spi(RenderingInternals)
    func draw(into canvas: TerminalCanvas, at origin: Point)
}

public extension View {
    @_spi(RenderingInternals)
    func addHeader(_ header: String) -> Self {
        return self
    }

    func render() {
        body.render()
    }

    @_spi(RenderingInternals)
    func renderString() -> String {
        body.renderString()
    }

    @_spi(RenderingInternals)
    func measure() -> Size {
        body.measure()
    }

    @_spi(RenderingInternals)
    func draw(into canvas: TerminalCanvas, at origin: Point) {
        body.draw(into: canvas, at: origin)
    }

    // MARK: - Style modifiers

    /// Applies a foreground color to every character in the view.
    ///
    /// ```swift
    /// Text("Error").forgroundColor(.red).render()
    /// ```
    func forgroundColor(_ color: Color) -> Self {
        addHeader("\u{001B}[3\(color.ansi)m")
    }

    /// Fills the background of the view's cells with the given color.
    ///
    /// ```swift
    /// Text("Highlight").background(.yellow).render()
    /// ```
    func background(_ color: Color) -> Self {
        addHeader("\u{001B}[4\(color.ansi)m")
    }

    /// Renders the view with bold weight.
    ///
    /// ```swift
    /// Text("Important").bold().render()
    /// ```
    func bold() -> Self {
        addHeader("\u{001B}[1m")
    }

    /// Renders the view with bold weight when `isActive` is `true`.
    ///
    /// - Parameter isActive: When `true`, bold is applied; otherwise the view
    ///   is rendered with its default weight.
    func bold(_ isActive: Bool) -> Self {
        isActive ? addHeader("\u{001B}[1m") : self
    }

    /// Sets the font weight of the view.
    ///
    /// - Parameter weight: The desired ``Weight``. Passing `.default` leaves the
    ///   weight unchanged.
    func fontWeight(_ weight: Weight) -> Self {
        weight == .default ? self : addHeader("\u{001B}[\(weight.rawValue)m")
    }

    /// Renders the view in italics.
    ///
    /// > Note: Support depends on the terminal emulator.
    func italic() -> Self {
        addHeader("\u{001B}[3m")
    }

    /// Renders the view in italics when `isActive` is `true`.
    ///
    /// - Parameter isActive: When `true`, italic is applied.
    func italic(_ isActive: Bool) -> Self {
        isActive ? addHeader("\u{001B}[3m") : self
    }

    /// Underlines every character in the view.
    func underline() -> Self {
        addHeader("\u{001B}[4m")
    }

    /// Underlines every character in the view when `isActive` is `true`.
    ///
    /// - Parameter isActive: When `true`, underline is applied.
    func underline(_ isActive: Bool) -> Self {
        isActive ? addHeader("\u{001B}[4m") : self
    }

    /// Applies a blinking effect using the given ``BlinkStyle``.
    ///
    /// - Parameter style: The blink style. Pass `.none` to disable blinking.
    func blink(_ style: BlinkStyle) -> Self {
        style == .none ? self : addHeader("\u{001B}[\(style.rawValue)m")
    }

    /// Makes the view invisible while preserving its layout space.
    ///
    /// > Note: The view still occupies terminal columns even when hidden.
    func hidden() -> Self {
        addHeader("\u{001B}[8m")
    }

    /// Makes the view invisible when `isActive` is `true`.
    ///
    /// - Parameter isActive: When `true`, the view is hidden.
    func hidden(_ isActive: Bool) -> Self {
        isActive ? addHeader("\u{001B}[8m") : self
    }

    /// Draws a horizontal strikethrough line through the view's characters.
    func strikethrough() -> Self {
        addHeader("\u{001B}[9m")
    }

    /// Draws a horizontal strikethrough line when `isActive` is `true`.
    ///
    /// - Parameter isActive: When `true`, strikethrough is applied.
    func strikethrough(_ isActive: Bool) -> Self {
        isActive ? addHeader("\u{001B}[9m") : self
    }

    // MARK: - Internal layout helpers

    /// Computes the terminal ``Size`` of a rendered string.
    internal func _size(of text: String) -> Size {
        let plain = _stripANSI(text)
        var lines = plain.components(separatedBy: "\n")
        if lines.last == "" { lines.removeLast() }
        let height = lines.count
        let width  = lines.map { _visibleWidth($0) }.max() ?? 0
        return Size(width: width, height: height)
    }

    /// Strips ANSI escape sequences from a string, returning printable text only.
    internal func _stripANSI(_ s: String) -> String {
        var result = ""
        var i = s.startIndex
        while i < s.endIndex {
            if s[i] == "\u{001B}" {
                i = s.index(after: i)
                while i < s.endIndex {
                    let c = s[i]
                    i = s.index(after: i)
                    if c == "m" { break }
                }
            } else {
                result.append(s[i])
                i = s.index(after: i)
            }
        }
        return result
    }

    /// Returns the visible column width of a string, accounting for wide Unicode characters.
    ///
    /// Characters in CJK, full-width, and other double-width Unicode blocks are
    /// counted as two columns.
    internal func _visibleWidth(_ s: String) -> Int {
        s.unicodeScalars.reduce(0) { acc, scalar in
            let v = scalar.value
            let wide = (v >= 0x1100 && v <= 0x115F)
                || (v >= 0x2E80 && v <= 0x303E)
                || (v >= 0x3041 && v <= 0x33BF)
                || (v >= 0x33FF && v <= 0xA4CF)
                || (v >= 0xAC00 && v <= 0xD7FF)
                || (v >= 0xF900 && v <= 0xFAFF)
                || (v >= 0xFE30 && v <= 0xFE6F)
                || (v >= 0xFF00 && v <= 0xFF60)
                || (v >= 0xFFE0 && v <= 0xFFE6)
            return acc + (wide ? 2 : 1)
        }
    }
}
