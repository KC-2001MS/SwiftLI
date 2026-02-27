//
//  View.swift
//
//
//  Created by Keisuke Chinone on 2024/05/27.
//

import Foundation



/// View to display text in terminal
///  
/// This is the most basic view that displays text in the terminal.
///  
/// To display the string you want to display, declare it with the init(_ string: String) initializer.
/// ```swift
/// let text = Text("Hello SwiftLI!")
/// text.render()
/// ```
/// To display a character multiple times in a row, declare it with the init(repeating: Character,count: Int) initializer.
/// ```swift
/// let text = Text(repeating: "+", count: 10)
/// text.render()
/// ```
///  In addition, you can change the text style of the view.To change, adapt the respective modifier. Below is an example of changing the text color to red and bold text.
/// ```swift
/// let text = Text("Hello SwiftLI!").forgroundColor(.red).bold()
/// text.render()
/// ```
public struct Text: View, Sendable, Equatable {
    let header: String
    
    let contents: Array<String>
    
    /// Creates a text view that is displayed in the terminal.
    /// - Parameter key: String to be displayed in the terminal
    public init(
        _ key: LocalizedStringKey,
        tableName: String? = nil,
        bundle: Bundle? = nil,
        comment: StaticString? = nil
    ) {
        self.header = ""
        self.contents = [String(localized: key.localizationValue, table: tableName, bundle: bundle, comment: comment)]
    }
    /// Creates a text view that displays a string literal without localization.
    /// - Parameter content: A string to display without localization.
    public init(verbatim content: String) {
        self.header = ""
        self.contents = [content]
    }
    /// Creates a text view that displays a string literal without localization.
    /// - Parameter content: A string to display without localization.
    public init<S>(_ content: S) where S : StringProtocol {
        self.header = ""
        self.contents = [String(content)]
    }
    /// Creates a text view that is displayed in the terminal.
    /// - Parameters:
    ///   - repeating: String to be repeated
    ///   - count: Number of times text is repeated
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
    /// What the view displays
    public var body: [any View] {
        return []
    }
    
    public func addHeader(_ header: String) -> Self {
        return Text(header: header + self.header, contents: contents)
    }

    /// Methods for rendering text
    public func render() {
        for content in contents {
            print("\(header)\(content)\u{001B}[0m", terminator: "")
        }
    }

    /// Returns the rendered string without writing to stdout.
    public func renderString() -> String {
        var s = ""
        for content in contents {
            s += "\(header)\(content)\u{001B}[0m"
        }
        return s
    }

    public func measure() -> Size {
        let s = renderString()
        return _size(of: s.isEmpty ? " " : s)
    }

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

/// A type that represents part of your CLT's user interface and provides modifiers that you use to configure views.
public protocol View {
    @ViewBuilder
    /// What the view displays
    var body: [View] { get }

    func addHeader(_ header: String) -> Self
    /// Methods for rendering text
    func render()

    /// Returns the complete rendered output of this view as a plain `String`,
    /// without writing anything to stdout.
    ///
    /// Used by ``measure()`` and ``draw(into:at:)`` to avoid nested stdout
    /// redirection when views are composed inside ``HStack`` or ``VStack``.
    func renderString() -> String

    /// Returns the size (columns × rows) this view occupies when rendered.
    func measure() -> Size

    /// Draws this view into a ``TerminalCanvas`` at the given position.
    func draw(into canvas: TerminalCanvas, at origin: Point)
}

public extension View {
    func addHeader(_ header: String) -> Self {
        return self
    }

    /// Default implementation of the render function
    func render() {
        body.forEach {
            $0.render()
        }
    }

    /// Default renderString: concatenate each child's renderString.
    func renderString() -> String {
        body.map { $0.renderString() }.joined()
    }

    /// Default measure: use renderString() — no stdout redirection.
    func measure() -> Size {
        let text = renderString()
        return _size(of: text.isEmpty ? " " : text)
    }

    /// Default draw: use renderString() — no stdout redirection.
    func draw(into canvas: TerminalCanvas, at origin: Point) {
        let text = renderString()
        if text.isEmpty { return }
        let size = _size(of: text)
        canvas.expand(toFit: Rect(origin: origin, size: size))
        canvas.write(text, at: origin)
    }

    // MARK: - Style modifiers

    /// Applies a foreground color to the view.
    func forgroundColor(_ color: Color) -> Self {
        addHeader("\u{001B}[3\(color.ansi)m")
    }

    /// Applies a background color to the view.
    func background(_ color: Color) -> Self {
        addHeader("\u{001B}[4\(color.ansi)m")
    }

    /// Applies bold weight to the view.
    func bold() -> Self {
        addHeader("\u{001B}[1m")
    }

    /// Applies bold weight to the view conditionally.
    func bold(_ isActive: Bool) -> Self {
        isActive ? addHeader("\u{001B}[1m") : self
    }

    /// Sets the font weight of the view.
    func fontWeight(_ weight: Weight) -> Self {
        weight == .default ? self : addHeader("\u{001B}[\(weight.rawValue)m")
    }

    /// Applies italic styling to the view.
    func italic() -> Self {
        addHeader("\u{001B}[3m")
    }

    /// Applies italic styling to the view conditionally.
    func italic(_ isActive: Bool) -> Self {
        isActive ? addHeader("\u{001B}[3m") : self
    }

    /// Applies underline styling to the view.
    func underline() -> Self {
        addHeader("\u{001B}[4m")
    }

    /// Applies underline styling to the view conditionally.
    func underline(_ isActive: Bool) -> Self {
        isActive ? addHeader("\u{001B}[4m") : self
    }

    /// Applies a blink effect to the view.
    func blink(_ style: BlinkStyle) -> Self {
        style == .none ? self : addHeader("\u{001B}[\(style.rawValue)m")
    }

    /// Hides the view.
    func hidden() -> Self {
        addHeader("\u{001B}[8m")
    }

    /// Hides the view conditionally.
    func hidden(_ isActive: Bool) -> Self {
        isActive ? addHeader("\u{001B}[8m") : self
    }

    /// Applies strikethrough styling to the view.
    func strikethrough() -> Self {
        addHeader("\u{001B}[9m")
    }

    /// Applies strikethrough styling to the view conditionally.
    func strikethrough(_ isActive: Bool) -> Self {
        isActive ? addHeader("\u{001B}[9m") : self
    }

    // MARK: - Internal helpers

    /// Computes the ``Size`` of a rendered string.
    internal func _size(of text: String) -> Size {
        let plain = _stripANSI(text)
        var lines = plain.components(separatedBy: "\n")
        if lines.last == "" { lines.removeLast() }
        let height = lines.count
        let width  = lines.map { _visibleWidth($0) }.max() ?? 0
        return Size(width: width, height: height)
    }

    /// Strips ANSI escape sequences from a string.
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

    /// Returns the visible column width of a string (handles multi-width chars).
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
