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
/// line.
///
/// ## Width of a horizontal divider
///
/// - `Divider()` (no count) fills the **full terminal width**, recomputed on
///   every render — so it follows the window as it is resized.
/// - `Divider(n)` inside a stack spans the stack; standalone it is `n` columns.
///
/// ```swift
/// // Full-width rule that tracks the terminal size:
/// Divider().render()
///
/// // Vertical bar between two texts inside HStack:
/// HStack {
///     Text("Left")
///     Divider()
///     Text("Right")
/// }
///
/// // Horizontal rule spanning a VStack:
/// VStack {
///     Text("Section A")
///     Divider(9)
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

    /// Number of repetitions when rendered as a fixed-width **horizontal** line.
    public let count: Int

    /// Whether a horizontal divider stretches to the full terminal width.
    ///
    /// `true` for `Divider()` (unspecified width); `false` when an explicit
    /// count is given.
    public let fillsWidth: Bool

    // MARK: - Public initialisers

    /// Creates a divider that fills the full terminal width when horizontal.
    ///
    /// Inside an ``HStack`` it is a vertical bar as tall as the stack; anywhere
    /// else it is a horizontal line spanning every column of the terminal,
    /// recomputed as the window resizes.
    public init() {
        self.header = ""
        self.character = "-"
        self.verticalCharacter = "|"
        self.count = 1
        self.fillsWidth = true
    }

    /// Creates a fixed-width divider.
    ///
    /// - Parameter count: The number of columns for a horizontal divider. Inside
    ///   a ``VStack`` the divider instead spans the stack width.
    public init(_ count: Int) {
        self.header = ""
        self.character = "-"
        self.verticalCharacter = "|"
        self.count = count
        self.fillsWidth = false
    }

    /// Creates a divider with explicit horizontal and vertical characters.
    ///
    /// - Parameters:
    ///   - character: The character drawn for a horizontal divider.
    ///   - verticalCharacter: The character drawn for a vertical divider inside ``HStack``.
    ///   - count: The number of columns for a fixed-width horizontal divider.
    public init(character: Character, verticalCharacter: Character = "|", count: Int = 1) {
        self.header = ""
        self.character = character
        self.verticalCharacter = verticalCharacter
        self.count = count
        self.fillsWidth = false
    }

    init(header: String, character: Character, verticalCharacter: Character, count: Int, fillsWidth: Bool = false) {
        self.header = header
        self.character = character
        self.verticalCharacter = verticalCharacter
        self.count = count
        self.fillsWidth = fillsWidth
    }

    // MARK: - View (horizontal / default context)

    public var body: some View {
        Group(contents: [Text(header: self.header, repeating: self.character, count: self.count)])
    }

    @_spi(RenderingInternals)
    public func addHeader(_ newHeader: String) -> Self {
        Divider(header: newHeader + self.header, character: self.character, verticalCharacter: self.verticalCharacter, count: self.count, fillsWidth: self.fillsWidth)
    }

    /// Lowers this divider into a direction-adaptive ``RenderNode/divider`` node.
    ///
    /// The layout engine stretches the node to span the enclosing stack — a
    /// vertical line as tall as an ``HStack``, or a horizontal line as wide as
    /// a ``VStack`` — or, when `fillsWidth` is set, to the full terminal width.
    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        .divider(header: header, character: character, verticalCharacter: verticalCharacter, count: count, fillsWidth: fillsWidth)
    }

    // MARK: - Modifiers

    /// Changes the line style of the divider.
    ///
    /// - Parameter style: The desired ``LineStyle``.
    ///   - `.default`: uses `-` (horizontal) and `|` (vertical).
    ///   - `.double_line`: uses `=` (horizontal) and `‖` (vertical).
    /// - Returns: A new `Divider` with the updated characters.
    public func lineStyle(_ style: LineStyle) -> Divider {
        switch style {
        case .default:
            return .init(header: self.header, character: "-", verticalCharacter: "|", count: self.count, fillsWidth: self.fillsWidth)
        case .double_line:
            return .init(header: self.header, character: "=", verticalCharacter: "‖", count: self.count, fillsWidth: self.fillsWidth)
        }
    }
}
