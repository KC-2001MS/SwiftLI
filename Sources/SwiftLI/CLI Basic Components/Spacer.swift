//
//  Spacer.swift
//
//  Created by Keisuke Chinone on 2024/05/27.
//


/// A flexible space that adapts its direction to the layout context.
///
/// When placed inside an ``HStack``, `Spacer` inserts horizontal blank space
/// (columns).  In any other context — including ``VStack``, ``Group``, or a
/// top-level `body` — it inserts vertical blank lines (rows).
///
/// ```swift
/// // Horizontal gap of 4 columns between two texts inside HStack:
/// HStack {
///     Text("Left")
///     Spacer(4)
///     Text("Right")
/// }
///
/// // Blank line between two views inside VStack:
/// VStack {
///     Text("Section A")
///     Spacer()         // one blank line
///     Text("Section B")
/// }
/// ```
///
/// `Spacer(n)` is equivalent to the former `Break(n)` when used outside an ``HStack``.
public struct Spacer: View, Sendable, Equatable {
    let header: String

    /// Number of space columns (horizontal) or blank rows (vertical).
    public let count: Int

    // MARK: - Initialisers

    /// Creates a spacer of `count` units.
    ///
    /// - Parameter count: The number of columns (inside ``HStack``) or blank
    ///   rows (everywhere else) to insert.
    public init(_ count: Int) {
        self.header = ""
        self.count = count
    }

    /// Creates a single-unit spacer (one column or one blank row).
    public init() {
        self.header = ""
        self.count = 1
    }

    init(header: String, count: Int) {
        self.header = header
        self.count = count
    }

    // MARK: - View (vertical / default context)

    public var body: some View {
        Group(contents: [Text(repeating: "\n", count: count)])
    }

    @_spi(RenderingInternals)
    public func addHeader(_ header: String) -> Self {
        return Spacer(header: header + self.header, count: self.count)
    }

    // MARK: - Horizontal helpers (used by HStack)

    /// Size when used as a **horizontal** spacer inside ``HStack``.
    func horizontalMeasure() -> Size {
        Size(width: count, height: 1)
    }

    /// Draws horizontal blank space into `canvas` at `origin` (used by HStack).
    func drawHorizontal(into canvas: TerminalCanvas, at origin: Point) {
        let spaces = String(repeating: " ", count: count)
        canvas.expand(toFit: Rect(origin: origin, size: horizontalMeasure()))
        canvas.write(spaces, at: origin)
    }

    // MARK: - Modifiers

    /// Applies a background color to the spacer's cells.
    ///
    /// When used inside an ``HStack``, this colors the blank columns.
    /// Outside an ``HStack``, it colors the blank rows.
    ///
    /// - Parameter color: The background color to apply.
    public func background(_ color: Color) -> Spacer {
        return .init(header: "\(header)\u{001B}[4\(color.ansi)m", count: count)
    }
}
