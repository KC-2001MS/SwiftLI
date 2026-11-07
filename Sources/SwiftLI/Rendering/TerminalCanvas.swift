//
//  TerminalCanvas.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2024/05/27.
//

import Foundation

/// One character cell of a ``TerminalCanvas`` (and, through ``Frame``, of the
/// screen the renderer tracks).
///
/// Cells keep their style *structured* — the SGR prefix and the hyperlink are
/// separate from the glyph — so a row can be emitted as runs (one escape
/// sequence per style change) and two frames can be compared cell by cell.
struct TerminalCell: Equatable, Sendable {
    /// The glyph: one grapheme cluster, with any zero-width marks that were
    /// drawn after it attached. Empty for the second column of a wide glyph.
    var glyph: String
    /// The accumulated SGR prefix in force when the cell was written (`""` is
    /// the terminal default).
    var style: String
    /// The OSC 8 open sequence of the hyperlink covering the cell (`""` is none).
    var link: String
    /// Whether anything was ever drawn here. Unwritten cells are blank and are
    /// trimmed from the end of a row.
    var written: Bool
    /// The glyph's column width: `0` for a wide glyph's continuation cell.
    var width: UInt8

    /// A never-written cell.
    static let blank = TerminalCell(glyph: " ", style: "", link: "", written: false, width: 1)
}

/// A 2-D character grid that views can draw into before the result is flushed
/// to stdout all at once.
///
/// `TerminalCanvas` decouples *layout* from *output*: each view writes its
/// characters into the grid at the position assigned by its parent
/// (`HStack`, `VStack`, etc.), and only when `flush()` is called does the
/// assembled frame reach the terminal.
///
/// ### Coordinate system
///
/// ```
/// column:  0  1  2  3  4  …
/// row 0:   H  e  l  l  o
/// row 1:   W  o  r  l  d
/// row 2:   …
/// ```
///
/// The origin `(column: 0, row: 0)` is the **top-left** of the canvas,
/// mirroring ``Point/zero``.
///
/// ### Row windows
///
/// A canvas created with a row window (see the internal
/// `init(width:height:visibleRows:)`) materialises cells only for the rows in
/// that window. Rows outside it are still laid out — writes to them are parsed
/// so each row's visible width and the canvas height stay exact — but cost no
/// cell storage and are never turned into strings. A scrolled viewport uses
/// this to pay only for the rows it shows.
public final class TerminalCanvas: @unchecked Sendable {

    // MARK: - Storage

    /// Cells of the materialised rows (the rows in `window`, in order).
    private var cells: [[TerminalCell]]
    /// Per row (every row, materialised or not), each column's glyph width:
    /// `0`/`1`/`2` once written, `unwritten` before.
    private var columnWidths: [[UInt8]]
    private static let unwritten: UInt8 = 255
    private let window: Range<Int>
    /// When set, the layout engine skips drawing anything that lies entirely
    /// outside these rows (see ``TerminalCanvas`` on row windows).
    let culledRows: Range<Int>?
    private let lock = NSLock()

    /// Width of the canvas in character columns.
    public private(set) var width: Int
    /// Height of the canvas in character rows.
    public private(set) var height: Int

    // MARK: - Init

    /// Creates a blank canvas filled with spaces.
    /// - Parameters:
    ///   - width: Number of columns.
    ///   - height: Number of rows.
    public convenience init(width: Int, height: Int) {
        self.init(width: width, height: height, visibleRows: 0..<Int.max, cullsHiddenRows: false)
    }

    /// Creates a canvas that materialises cells only for `visibleRows`.
    ///
    /// With `cullsHiddenRows` the layout engine additionally skips subtrees
    /// that lie entirely outside the window; otherwise they are still laid out
    /// (and their widths tracked), just not stored.
    init(width: Int, height: Int, visibleRows: Range<Int>, cullsHiddenRows: Bool) {
        self.width = width
        self.height = height
        self.window = visibleRows
        self.culledRows = cullsHiddenRows ? visibleRows : nil
        // A culling canvas never draws outside its window, so it tracks widths
        // only for the window's rows too; otherwise every row is tracked.
        self.tracksAllRows = !cullsHiddenRows
        let materialised = Self.materialisedRowCount(height: height, window: visibleRows)
        self.columnWidths = Array(repeating: Array(repeating: Self.unwritten, count: width), count: cullsHiddenRows ? materialised : height)
        self.cells = Array(repeating: Array(repeating: .blank, count: width), count: materialised)
    }

    private let tracksAllRows: Bool

    private static func materialisedRowCount(height: Int, window: Range<Int>) -> Int {
        Swift.max(0, Swift.min(height, window.upperBound) - window.lowerBound)
    }

    /// The index into `cells` for `row`, or `-1` when the row isn't materialised.
    @inline(__always)
    private func materialisedIndex(of row: Int) -> Int {
        window.contains(row) ? row - window.lowerBound : -1
    }

    /// The index into `columnWidths` for `row`, or `-1` when the row's widths
    /// aren't tracked (a row outside a culling canvas's window).
    @inline(__always)
    private func widthsIndex(of row: Int) -> Int {
        tracksAllRows ? row : materialisedIndex(of: row)
    }

    // MARK: - Drawing

    static let reset = "\u{001B}[0m"
    /// The ST-terminated close for an OSC 8 hyperlink.
    static let linkClose = "\u{001B}]8;;\u{001B}\\"
    /// Single-character strings for every ASCII byte, so the common glyph
    /// needs no allocation.
    private static let asciiGlyphs: [String] = (0..<128).map { String(UnicodeScalar(UInt8($0))) }

    /// Writes a styled string into the canvas starting at `origin`.
    ///
    /// The string is split on `\n`: each segment fills the current row from
    /// `origin.column`, then the row advances by one.  Characters that fall
    /// outside the canvas bounds are silently clipped.
    ///
    /// - Parameters:
    ///   - text: The raw string to write (may contain ANSI escape sequences).
    ///   - origin: The top-left cell to start writing at.
    public func write(_ text: String, at origin: Point) {
        lock.lock()
        defer { lock.unlock() }

        let segments = text.components(separatedBy: "\n")
        var row = origin.row
        // activeStyle tracks all currently-open SGR sequences so every visible
        // character in the run inherits the same style. activeLink separately
        // tracks an open OSC 8 hyperlink.
        var activeStyle = ""
        var activeLink = ""
        for segment in segments {
            guard row < height else { break }
            let materialised = materialisedIndex(of: row)
            var col = origin.column

            // Scan the UTF-8 bytes: escape sequences and plain ASCII — the
            // bulk of any frame — are handled bytewise; only clusters that
            // might be wider than one byte go through grapheme segmentation.
            let utf8 = segment.utf8
            let end = utf8.endIndex
            var i = utf8.startIndex
            while i < end {
                let byte = utf8[i]
                if byte == 0x1B {
                    let sequenceStart = i
                    i = utf8.index(after: i)
                    if i < end, utf8[i] == 0x5D { // "]"
                        // OSC (hyperlink): accumulate until BEL or ST (`\e\`).
                        i = utf8.index(after: i)
                        while i < end {
                            let c = utf8[i]
                            i = utf8.index(after: i)
                            if c == 0x07 { break }
                            if c == 0x1B {
                                if i < end, utf8[i] == 0x5C { i = utf8.index(after: i) }
                                break
                            }
                        }
                        let sequence = String(segment[sequenceStart..<i])
                        // An empty-URI OSC 8 closes the link; anything else opens one.
                        activeLink = (sequence == Self.linkClose) ? "" : sequence
                    } else {
                        // CSI (SGR): accumulate up to and including its 'm'.
                        while i < end {
                            let c = utf8[i]
                            i = utf8.index(after: i)
                            if c == 0x6D { break }
                        }
                        let sequence = String(segment[sequenceStart..<i])
                        if sequence == Self.reset {
                            activeStyle = ""
                        } else {
                            activeStyle += sequence
                        }
                    }
                    continue
                }

                let glyph: String
                let w: Int
                let next = utf8.index(after: i)
                if byte < 0x80, byte != 0x0D, next == end || utf8[next] < 0x80 {
                    // A lone ASCII byte is a one-column cluster of its own. (One
                    // followed by a non-ASCII scalar may be the start of a longer
                    // cluster — a keycap, a combining mark — and CR LF is the one
                    // all-ASCII pair; both take the general path.)
                    glyph = Self.asciiGlyphs[Int(byte)]
                    w = 1
                    i = next
                } else {
                    let ch = segment[i]
                    glyph = String(ch)
                    // Advance the column by the glyph's visible width so wide
                    // glyphs (CJK, emoji) stay aligned with the layout, which
                    // also measures them as two columns.
                    w = TextMetrics.width(of: ch)
                    i = utf8.index(i, offsetBy: ch.utf8.count)
                }

                put(glyph: glyph, width: w, style: activeStyle, link: activeLink, row: row, materialised: materialised, column: &col)
            }
            row += 1
        }
    }

    /// Writes plain `lines` — one per row, free of escape sequences — starting
    /// at `origin`, every glyph carrying `sgr` and `link`.
    ///
    /// Produces exactly the cells ``write(_:at:)`` would for the same lines
    /// wrapped in the style's escape prefix and a reset, without composing
    /// that string and parsing it back.
    func write(lines: [String], sgr: String, link: String, at origin: Point) {
        lock.lock()
        defer { lock.unlock() }

        var row = origin.row
        for line in lines {
            guard row < height else { break }
            let materialised = materialisedIndex(of: row)
            var col = origin.column
            let utf8 = line.utf8
            let end = utf8.endIndex
            var i = utf8.startIndex
            while i < end {
                let byte = utf8[i]
                let next = utf8.index(after: i)
                if byte < 0x80, byte != 0x0D, next == end || utf8[next] < 0x80 {
                    put(glyph: Self.asciiGlyphs[Int(byte)], width: 1, style: sgr, link: link, row: row, materialised: materialised, column: &col)
                    i = next
                } else {
                    let ch = line[i]
                    put(glyph: String(ch), width: TextMetrics.width(of: ch), style: sgr, link: link, row: row, materialised: materialised, column: &col)
                    i = utf8.index(i, offsetBy: ch.utf8.count)
                }
            }
            row += 1
        }
    }

    /// Copies a row of cells (as ``cellRows()`` returns them) into the canvas
    /// starting at `origin`.
    ///
    /// Equivalent to writing the row's emitted string, without composing the
    /// escape sequences and parsing them back: the cells of a scrolled
    /// viewport's window move from the content's canvas to the frame's in one
    /// step. A wide glyph's continuation cell is skipped — placing the glyph
    /// claims it, exactly as the string path does.
    func write(cells row: [TerminalCell], at origin: Point) {
        lock.lock()
        defer { lock.unlock() }
        guard origin.row < height else { return }
        let materialised = materialisedIndex(of: origin.row)
        var col = origin.column
        // Each glyph is placed as the parsed string's would be: a wide glyph
        // claims the cell after it, so the source's continuation cells
        // (width 0) are skipped rather than copied.
        for cell in row where cell.width > 0 {
            put(glyph: cell.glyph, width: Int(cell.width), style: cell.style, link: cell.link, row: origin.row, materialised: materialised, column: &col)
        }
    }

    /// Places one glyph at `column` of `row` and advances the column by its
    /// width. A zero-width mark composes onto the previous cell instead of
    /// consuming a column; a wide glyph also claims the cell after it, so the
    /// real character at `column + 2` is not overwritten.
    @inline(__always)
    private func put(glyph: String, width w: Int, style: String, link: String, row: Int, materialised: Int, column col: inout Int) {
        let tracked = widthsIndex(of: row)
        if w == 0 {
            if col > 0, col - 1 < width {
                if materialised >= 0 {
                    cells[materialised][col - 1].glyph += glyph
                    cells[materialised][col - 1].written = true
                }
                if tracked >= 0, columnWidths[tracked][col - 1] == Self.unwritten {
                    columnWidths[tracked][col - 1] = 1
                }
            }
            return
        }
        if col >= 0, col < width {
            if tracked >= 0 { columnWidths[tracked][col] = UInt8(w) }
            if materialised >= 0 {
                cells[materialised][col] = TerminalCell(glyph: glyph, style: style, link: link, written: true, width: UInt8(w))
            }
            if w >= 2, col + 1 < width {
                if tracked >= 0 { columnWidths[tracked][col + 1] = 0 }
                if materialised >= 0 {
                    cells[materialised][col + 1] = TerminalCell(glyph: "", style: "", link: "", written: true, width: 0)
                }
            }
        }
        col += w
    }

    /// Expands the canvas to fit `rect` if needed, filling new cells with spaces.
    public func expand(toFit rect: Rect) {
        lock.lock()
        defer { lock.unlock() }

        let neededWidth  = rect.maxColumn
        let neededHeight = rect.maxRow

        if neededHeight > height {
            let materialised = Self.materialisedRowCount(height: neededHeight, window: window)
            let trackedRows = tracksAllRows ? neededHeight : materialised
            if trackedRows > columnWidths.count {
                columnWidths.append(contentsOf: Array(repeating: Array(repeating: Self.unwritten, count: width), count: trackedRows - columnWidths.count))
            }
            if materialised > cells.count {
                cells.append(contentsOf: Array(repeating: Array(repeating: .blank, count: width), count: materialised - cells.count))
            }
            height = neededHeight
        }
        if neededWidth > width {
            let extra = neededWidth - width
            for r in columnWidths.indices {
                columnWidths[r].append(contentsOf: Array(repeating: Self.unwritten, count: extra))
            }
            for r in cells.indices {
                cells[r].append(contentsOf: Array(repeating: .blank, count: extra))
            }
            width = neededWidth
        }
    }

    // MARK: - Output

    /// Writes the entire canvas to stdout row by row, trimming trailing spaces.
    ///
    /// Every row (including the last) is terminated with `\n` so that
    /// subsequent `render()` calls always start on a fresh line.
    public func flush() {
        for line in lines() {
            print(line)
        }
    }

    // MARK: - Helpers

    /// Returns the canvas rows as an array of strings, one per row, with
    /// trailing blank (never-written) cells trimmed.
    ///
    /// This is the bridge from the mutable canvas to an immutable ``Frame``.
    /// A row-windowed canvas returns only its materialised rows.
    public func lines() -> [String] {
        cellRows().map { Self.emit($0[...]) }
    }

    /// Returns the rendered content as a plain `String` (useful for testing).
    /// Trailing spaces on each row are trimmed.
    public func toString() -> String {
        lines().joined(separator: "\n")
    }

    /// The materialised rows as cells, each trimmed of trailing never-written cells.
    func cellRows() -> [[TerminalCell]] {
        lock.lock()
        defer { lock.unlock() }
        return cells.indices.map { r in
            Array(cells[r].prefix(writtenCount(tracked: widthsIndex(of: r + window.lowerBound))))
        }
    }

    /// The visible width of every row: the columns up to and including the
    /// last written cell, wide glyphs counted as two. Rows a culling canvas
    /// never draws (outside its window) report zero.
    func lineWidths() -> [Int] {
        lock.lock()
        defer { lock.unlock() }
        return (0..<height).map { row in
            let tracked = widthsIndex(of: row)
            guard tracked >= 0 else { return 0 }
            var total = 0
            for w in columnWidths[tracked].prefix(writtenCount(tracked: tracked)) {
                total += w == Self.unwritten ? 1 : Int(w)
            }
            return total
        }
    }

    /// The number of leading columns up to and including the last written
    /// cell of the row whose widths live at `tracked`.
    private func writtenCount(tracked: Int) -> Int {
        let widths = columnWidths[tracked]
        var c = widths.count
        while c > 0, widths[c - 1] == Self.unwritten { c -= 1 }
        return c
    }

    /// Lowers a run of cells to terminal output.
    ///
    /// Styles are emitted as runs: an SGR prefix is written only where it
    /// changes from the previous cell (preceded by a reset when a different
    /// style was active), a hyperlink is opened once and closed when the run
    /// leaves it, and both are closed at the end. Each cell still displays
    /// exactly the style it was written with — the output is just the compact
    /// form of writing every cell with its own prefix and reset.
    static func emit(_ cells: ArraySlice<TerminalCell>) -> String {
        // Assembled as UTF-8 bytes and decoded once: appending a few bytes to
        // a byte array is several times cheaper than appending a short
        // `String` to a `String`, and a frame emits every cell of every row.
        var out: [UInt8] = []
        out.reserveCapacity(cells.count + 16)
        var activeStyle = ""
        var activeLink = ""
        for cell in cells {
            if cell.link != activeLink {
                if !activeLink.isEmpty { out.append(contentsOf: linkClose.utf8) }
                if !cell.link.isEmpty { out.append(contentsOf: cell.link.utf8) }
                activeLink = cell.link
            }
            if cell.style != activeStyle {
                if !activeStyle.isEmpty { out.append(contentsOf: reset.utf8) }
                out.append(contentsOf: cell.style.utf8)
                activeStyle = cell.style
            }
            out.append(contentsOf: cell.glyph.utf8)
        }
        if !activeStyle.isEmpty { out.append(contentsOf: reset.utf8) }
        if !activeLink.isEmpty { out.append(contentsOf: linkClose.utf8) }
        return String(decoding: out, as: UTF8.self)
    }
}
