//
//  Divider.swift
//
//
//  Created by Keisuke Chinone on 2024/05/28.
//


/// A visual separator that adapts its orientation to the layout context.
///
/// When placed inside an ``HStack``, `Divider` draws a **vertical** line
/// (one column wide, as tall as the stack).  In any other context —
/// ``VStack``, ``Group``, or a top-level `body` — it draws a **horizontal**
/// line (`character` repeated `count` times).
///
/// ```swift
/// // Vertical bar between two texts inside HStack:
/// HStack {
///     Text("Left")
///     Divider()
///     Text("Right")
/// }
///
/// // Horizontal rule between two sections inside VStack:
/// VStack {
///     Text("Section A")
///     Divider()
///     Text("Section B")
/// }
/// ```
///
/// Use ``lineStyle(_:)`` to change the line characters (`-`/`|` or `=`/`‖`).
public struct Divider: View, Sendable, Equatable {
    let header: String

    /// The character used for the horizontal line (default: `-`).
    public let character: Character

    /// The character used for the vertical line inside an ``HStack`` (default: `|`).
    public let verticalCharacter: Character

    /// Number of repetitions when rendered as a **horizontal** line.
    public let count: Int

    // MARK: - Public initialisers

    /// Creates a divider with the default characters (`-` horizontal, `|` vertical) and `count` columns wide.
    public init(_ count: Int = 1) {
        self.header = ""
        self.character = "-"
        self.verticalCharacter = "|"
        self.count = count
    }

    /// Creates a divider with explicit characters and width.
    public init(character: Character, verticalCharacter: Character = "|", count: Int = 1) {
        self.header = ""
        self.character = character
        self.verticalCharacter = verticalCharacter
        self.count = count
    }

    init(header: String, character: Character, verticalCharacter: Character, count: Int) {
        self.header = header
        self.character = character
        self.verticalCharacter = verticalCharacter
        self.count = count
    }

    // MARK: - View (horizontal / default context)

    /// Default body: horizontal line (used outside HStack).
    public var body: [View] {
        Text(header: self.header, repeating: self.character, count: self.count)
    }

    public func addHeader(_ newHeader: String) -> Self {
        Divider(header: newHeader + self.header, character: self.character, verticalCharacter: self.verticalCharacter, count: self.count)
    }

    // MARK: - Vertical helpers (used by HStack)

    /// Draws a vertical divider into `canvas` at `origin` (used by HStack).
    /// Height is the full height of the enclosing HStack.
    func drawVertical(into canvas: TerminalCanvas, at origin: Point, height: Int) {
        let size = Size(width: 1, height: height)
        canvas.expand(toFit: Rect(origin: origin, size: size))
        for row in 0..<height {
            let cell = header + String(verticalCharacter) + "\u{001B}[0m"
            canvas.write(cell, at: Point(column: origin.column, row: origin.row + row))
        }
    }

    // MARK: - Horizontal helpers (used by VStack)

    /// Draws a horizontal divider into `canvas` at `origin` spanning `width` columns (used by VStack).
    /// Width is the full width of the enclosing VStack.
    func drawHorizontal(into canvas: TerminalCanvas, at origin: Point, width: Int) {
        let size = Size(width: width, height: 1)
        canvas.expand(toFit: Rect(origin: origin, size: size))
        let cell = header + String(repeating: character, count: width) + "\u{001B}[0m"
        canvas.write(cell, at: origin)
    }

    // MARK: - Modifiers

    /// Specifies the line style of the divider.
    public func lineStyle(_ style: LineStyle) -> Divider {
        switch style {
        case .default:
            return .init(header: self.header, character: "-", verticalCharacter: "|", count: self.count)
        case .double_line:
            return .init(header: self.header, character: "=", verticalCharacter: "‖", count: self.count)
        }
    }
}
