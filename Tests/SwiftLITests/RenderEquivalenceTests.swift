//
//  RenderEquivalenceTests.swift
//  SwiftLITests
//
//  Created by Keisuke Chinone on 2026/11/06.
//
//  The rendering fast paths (ASCII text metrics, plain-run text sizing,
//  structured canvas cells with run-length output, the cell-level screen diff
//  with hardware scrolling) must produce exactly what the straightforward
//  implementations produce. These tests pin that down against reference
//  implementations and a small terminal emulator, over randomised input.

import Testing
import Foundation
@_spi(RenderingInternals) @testable import SwiftLI

// MARK: - Deterministic randomness

private struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

private let sampleGlyphs: [String] = [
    "a", "Z", "0", " ", "-", "日", "本", "é", "e\u{301}", "👍", "👨‍👩‍👧", "🇯🇵", "1️⃣", "ｱ", "\t", "\u{301}",
]
// A cluster that stands alone only at the start of a string or after a
// control character. The pre-optimisation parsers walked escape sequences by
// `Character`, so a mark directly after a sequence's final byte was swallowed
// into the sequence; the byte-based parsers read it as content. The reference
// comparisons below therefore never place one right after an escape or a
// newline (a lone ZWJ is excluded altogether: it re-joins the previous glyph
// on re-parse, in the old and new code alike).
private func isLoneMark(_ s: Substring) -> Bool {
    s.first.map { TextMetrics.width(of: $0) == 0 } ?? false
}
private let sampleStyles: [TextStyle] = [
    .plain,
    TextStyle(foreground: .red),
    TextStyle(foreground: .cyan, weight: .bold),
    TextStyle(background: .eightBit(236)),
    TextStyle(foreground: .eightBit(240), background: .eightBit(236), isUnderlined: true),
    TextStyle(link: "https://example.com/a"),
    TextStyle(foreground: .yellow, link: "https://example.com/b"),
]

private func randomPlainString(_ rng: inout SplitMix64, maxLength: Int = 12, newlines: Bool = false) -> String {
    let length = Int.random(in: 0...maxLength, using: &rng)
    var s = ""
    var atLineStart = true
    for _ in 0..<length {
        if newlines, Int.random(in: 0..<10, using: &rng) == 0 {
            s += Bool.random(using: &rng) ? "\n" : "\r\n"
            atLineStart = true
        } else {
            var glyph = sampleGlyphs.randomElement(using: &rng)!
            if atLineStart, isLoneMark(glyph[...]) { glyph = "a" + glyph }
            s += glyph
            atLineStart = false
        }
    }
    return s
}

/// A random styled string in the exact form the layout engine composes.
private func randomStyledRun(_ rng: inout SplitMix64) -> String {
    let style = sampleStyles.randomElement(using: &rng)!
    return style.ansiPrefix + randomPlainString(&rng) + "\u{001B}[0m"
}

// MARK: - Reference implementations (the pre-optimisation code paths)

private enum Legacy {
    static func width(of character: Character) -> Int {
        let scalars = character.unicodeScalars
        let isEmoji: Bool = {
            if scalars.contains(where: { $0.value == 0x200D }) { return true }
            if scalars.contains(where: { $0.value == 0xFE0F }) && scalars.contains(where: { $0.properties.isEmoji }) { return true }
            if scalars.allSatisfy({ (0x1F1E6...0x1F1FF).contains($0.value) }) && scalars.count >= 2 { return true }
            return scalars.contains { $0.properties.isEmojiPresentation }
        }()
        if isEmoji { return 2 }
        guard let base = scalars.first else { return 0 }
        if base.properties.isDefaultIgnorableCodePoint { return 0 }
        switch base.properties.generalCategory {
        case .nonspacingMark, .enclosingMark, .format: return 0
        default: break
        }
        let v = base.value
        let wide = (v >= 0x1100 && v <= 0x115F) || (v >= 0x2E80 && v <= 0x303E) || v == 0x3000
            || (v >= 0x3041 && v <= 0x33BF) || (v >= 0x33FF && v <= 0xA4CF) || (v >= 0xAC00 && v <= 0xD7A3)
            || (v >= 0xF900 && v <= 0xFAFF) || (v >= 0xFE30 && v <= 0xFE4F) || (v >= 0xFF00 && v <= 0xFF60)
            || (v >= 0xFFE0 && v <= 0xFFE6) || (v >= 0x1F300 && v <= 0x1FAFF) || (v >= 0x20000 && v <= 0x3FFFD)
        return wide ? 2 : 1
    }

    static func visibleWidth(_ s: String) -> Int { s.reduce(0) { $0 + width(of: $1) } }

    static func stripANSI(_ s: String) -> String {
        var result = ""
        var i = s.startIndex
        while i < s.endIndex {
            if s[i] == "\u{001B}" {
                i = s.index(after: i)
                guard i < s.endIndex else { break }
                if s[i] == "]" {
                    i = s.index(after: i)
                    while i < s.endIndex {
                        let c = s[i]
                        if c == "\u{0007}" { i = s.index(after: i); break }
                        if c == "\u{001B}" {
                            i = s.index(after: i)
                            if i < s.endIndex, s[i] == "\\" { i = s.index(after: i) }
                            break
                        }
                        i = s.index(after: i)
                    }
                } else {
                    while i < s.endIndex {
                        let c = s[i]
                        i = s.index(after: i)
                        if c == "m" { break }
                    }
                }
            } else {
                result.append(s[i])
                i = s.index(after: i)
            }
        }
        return result
    }

    static func size(of text: String) -> Size {
        let plain = stripANSI(text)
        var lines = plain.components(separatedBy: "\n")
        if lines.last == "" { lines.removeLast() }
        return Size(width: lines.map { visibleWidth($0) }.max() ?? 0, height: lines.count)
    }
}

// MARK: - Text metrics

@Suite("Text Metrics Equivalence")
struct TextMetricsEquivalenceTests {

    @Test("visibleWidth and width(of:) agree with the per-cluster reference")
    func widths() {
        var rng = SplitMix64(seed: 1)
        for _ in 0..<2000 {
            let s = randomPlainString(&rng, maxLength: 20, newlines: true)
            #expect(TextMetrics.visibleWidth(s) == Legacy.visibleWidth(s), "\(s.debugDescription)")
            for ch in s {
                #expect(TextMetrics.width(of: ch) == Legacy.width(of: ch), "\(ch.debugDescription)")
            }
        }
        // Control characters and CR LF count as the reference counts them.
        for s in ["\u{1}\u{2}", "\r\n", "a\r\nb", "\u{7F}", "\t\t"] {
            #expect(TextMetrics.visibleWidth(s) == Legacy.visibleWidth(s), "\(s.debugDescription)")
        }
    }

    @Test("stripANSI matches the character-by-character reference")
    func strip() {
        var rng = SplitMix64(seed: 2)
        for _ in 0..<2000 {
            var s = ""
            for _ in 0..<Int.random(in: 0...4, using: &rng) {
                s += randomStyledRun(&rng)
                if Bool.random(using: &rng) { s += randomPlainString(&rng) }
            }
            // Also exercise BEL-terminated links and dangling sequences.
            switch Int.random(in: 0..<6, using: &rng) {
            case 0: s += "\u{001B}]8;;https://x\u{0007}link\u{001B}]8;;\u{0007}"
            case 1: s += "\u{001B}[3"
            case 2: s += "\u{001B}"
            case 3: s += "\u{001B}]8;;unterminated"
            default: break
            }
            #expect(TextMetrics.stripANSI(s) == Legacy.stripANSI(s), "\(s.debugDescription)")
        }
    }

    @Test("Text nodes measure exactly as their composed string did")
    func textSize() {
        var rng = SplitMix64(seed: 3)
        for _ in 0..<3000 {
            let runs = (0..<Int.random(in: 0...3, using: &rng)).map { _ in randomPlainString(&rng, maxLength: 30, newlines: true) }
            let style = sampleStyles.randomElement(using: &rng)!
            let proposed: Int? = Bool.random(using: &rng) ? nil : Int.random(in: 0...12, using: &rng)
            let limit: Int? = Bool.random(using: &rng) ? nil : Int.random(in: 0...3, using: &rng)
            let composed = NodeLayout.styledText(style: style, contents: runs, proposedWidth: proposed, lineLimit: limit)
            let expected = Legacy.size(of: composed.isEmpty ? " " : composed)
            let actual = NodeLayout.textSize(style: style, contents: runs, proposedWidth: proposed, lineLimit: limit)
            #expect(actual == expected, "runs=\(runs) proposed=\(String(describing: proposed)) limit=\(String(describing: limit))")
        }
        // Runs that carry their own escapes still go through the composed string.
        let raw = ["\u{001B}[31mred\u{001B}[0m", "plain"]
        #expect(NodeLayout.textSize(style: .plain, contents: raw, proposedWidth: nil, lineLimit: nil) == Legacy.size(of: NodeLayout.styledText(style: .plain, contents: raw)))
    }

    @Test("truncate leaves a fitting line untouched and cuts like the reference walk")
    func truncate() {
        var rng = SplitMix64(seed: 4)
        for _ in 0..<1000 {
            let line = (0..<Int.random(in: 1...3, using: &rng)).map { _ in randomStyledRun(&rng) }.joined()
            let width = TextMetrics.visibleWidth(TextMetrics.stripANSI(line))
            // (A zero-column limit always yields "", as it always did.)
            if width > 0 { #expect(TextMetrics.truncate(line, toColumns: width) == line) }
            #expect(TextMetrics.truncate(line, toColumns: width + 5) == line)
            let limit = Int.random(in: 0...max(0, width), using: &rng)
            let cut = TextMetrics.truncate(line, toColumns: limit)
            #expect(TextMetrics.visibleWidth(TextMetrics.stripANSI(cut)) <= limit)
            // Everything kept is a prefix of the visible text.
            #expect(TextMetrics.stripANSI(line).hasPrefix(TextMetrics.stripANSI(cut)))
        }
    }
}

// MARK: - Canvas

@Suite("Canvas Equivalence")
struct CanvasEquivalenceTests {

    /// Random writes into a canvas; returns the same writes so a second canvas
    /// can replay them.
    private func randomWrites(_ rng: inout SplitMix64, rows: Int, columns: Int) -> [(String, Point)] {
        (0..<Int.random(in: 1...40, using: &rng)).map { _ in
            var text = ""
            for _ in 0..<Int.random(in: 1...3, using: &rng) { text += randomStyledRun(&rng) }
            if Int.random(in: 0..<4, using: &rng) == 0 { text += "\n" + randomStyledRun(&rng) }
            return (text, Point(column: Int.random(in: 0..<columns, using: &rng), row: Int.random(in: 0..<rows, using: &rng)))
        }
    }

    @Test("Copying a row's cells into a canvas matches writing its emitted string")
    func cellCopyMatchesStringWrite() {
        var rng = SplitMix64(seed: 0x5CA1_AB1E)
        for _ in 0..<200 {
            let rows = Int.random(in: 1...6, using: &rng)
            let columns = Int.random(in: 4...30, using: &rng)
            let source = TerminalCanvas(width: columns, height: rows)
            for (text, point) in randomWrites(&rng, rows: rows, columns: columns) {
                source.write(text, at: point)
            }
            let viaCells = TerminalCanvas(width: 0, height: 0)
            let viaStrings = TerminalCanvas(width: 0, height: 0)
            let origin = Point(column: Int.random(in: 0...3, using: &rng), row: Int.random(in: 0...2, using: &rng))
            let size = Size(width: columns + origin.column, height: rows + origin.row)
            viaCells.expand(toFit: Rect(origin: .zero, size: size))
            viaStrings.expand(toFit: Rect(origin: .zero, size: size))
            for (row, cells) in source.cellRows().enumerated() {
                let point = Point(column: origin.column, row: origin.row + row)
                viaCells.write(cells: cells, at: point)
                viaStrings.write(TerminalCanvas.emit(cells[...]), at: point)
            }
            #expect(viaCells.cellRows() == viaStrings.cellRows())
            #expect(viaCells.lineWidths() == viaStrings.lineWidths())
        }
    }

    @Test("Placing a frame's block as cells matches composing it as strings")
    func frameBlockCellsMatchStrings() {
        var rng = SplitMix64(seed: 0xF4A3_E0B1)
        let alignments: [Alignment] = [.topLeading, .top, .topTrailing, .leading, .center, .trailing, .bottomLeading, .bottom, .bottomTrailing]
        for _ in 0..<300 {
            let rows = Int.random(in: 0...6, using: &rng)
            let columns = Int.random(in: 1...24, using: &rng)
            let child = TerminalCanvas(width: columns, height: rows)
            if rows > 0 {
                for (text, point) in randomWrites(&rng, rows: rows, columns: columns) { child.write(text, at: point) }
            }
            let width = Int.random(in: 1...30, using: &rng)
            let height = Int.random(in: 1...8, using: &rng)
            let alignment = alignments[Int.random(in: 0..<alignments.count, using: &rng)]
            let origin = Point(column: Int.random(in: 0...2, using: &rng), row: Int.random(in: 0...2, using: &rng))
            let size = Size(width: origin.column + width, height: origin.row + height)

            let viaStrings = TerminalCanvas(width: 0, height: 0)
            viaStrings.expand(toFit: Rect(origin: .zero, size: size))
            let block = NodeLayout.composeFrameBlock(child.lines(), width: width, height: height, alignment: alignment)
            for (row, line) in block.enumerated() where !line.isEmpty {
                viaStrings.write(line, at: Point(column: origin.column, row: origin.row + row))
            }

            let viaCells = TerminalCanvas(width: 0, height: 0)
            viaCells.expand(toFit: Rect(origin: .zero, size: size))
            NodeLayout.placeFrameBlock(child.cellRows(), width: width, height: height, alignment: alignment, into: viaCells, at: origin)

            #expect(viaCells.lines() == viaStrings.lines())
            #expect(viaCells.lineWidths() == viaStrings.lineWidths())
        }
    }

    @Test("A row-windowed canvas reports the same rows and widths as a full one")
    func windowedCanvas() {
        var rng = SplitMix64(seed: 5)
        for _ in 0..<300 {
            let rows = Int.random(in: 1...30, using: &rng)
            let columns = Int.random(in: 1...40, using: &rng)
            let writes = randomWrites(&rng, rows: rows, columns: columns)
            let start = Int.random(in: 0..<rows, using: &rng)
            let window = start..<min(rows, start + Int.random(in: 1...8, using: &rng))

            let full = TerminalCanvas(width: 0, height: 0)
            let windowed = TerminalCanvas(width: 0, height: 0, visibleRows: window, cullsHiddenRows: false)
            for canvas in [full, windowed] {
                canvas.expand(toFit: Rect(origin: .zero, size: Size(width: columns, height: rows)))
                for (text, origin) in writes { canvas.write(text, at: origin) }
            }
            let fullLines = full.lines()
            #expect(windowed.lines() == Array(fullLines[window]))
            #expect(windowed.lineWidths() == full.lineWidths())
            // The tracked width is the visible width of the emitted line.
            for (row, line) in fullLines.enumerated() {
                #expect(full.lineWidths()[row] == TextMetrics.visibleWidth(TextMetrics.stripANSI(line)))
            }
        }
    }

    @Test("Emitted rows parse back into identical cells")
    func roundTrip() {
        var rng = SplitMix64(seed: 6)
        for _ in 0..<300 {
            let rows = Int.random(in: 1...10, using: &rng)
            let columns = Int.random(in: 1...40, using: &rng)
            let source = TerminalCanvas(width: columns, height: rows)
            // One write per row: a later write over the first half of a wide
            // glyph leaves its orphaned second half, which (in the old cell
            // format just the same) shifts the rest of the row on re-parse.
            for row in 0..<rows {
                var text = randomStyledRun(&rng)
                if Bool.random(using: &rng) { text += randomStyledRun(&rng) }
                source.write(text, at: Point(column: Int.random(in: 0..<columns, using: &rng), row: row))
            }
            let lines = source.lines()
            let replay = TerminalCanvas(width: columns, height: rows)
            for (row, line) in lines.enumerated() { replay.write(line, at: Point(column: 0, row: row)) }
            let original = source.cellRows()
            let parsed = replay.cellRows()
            #expect(original.count == parsed.count)
            for (a, b) in zip(original, parsed) {
                #expect(a.count == b.count)
                for (x, y) in zip(a, b) {
                    // A written cell survives exactly; an unwritten one comes
                    // back as the plain space it was emitted as.
                    if x.written {
                        #expect(x == y)
                    } else {
                        #expect(y.glyph == " " && y.style == "" && y.link == "")
                    }
                }
            }
            // Every row closes every style and link it opens: the last SGR
            // is a reset whenever any other SGR occurs, and the last OSC 8 is
            // a close whenever a link was opened.
            for line in lines where line.contains("\u{001B}") {
                let sgrs = line.ranges(of: /\u{1B}\[[0-9;]*m/).map { String(line[$0]) }
                if sgrs.contains(where: { $0 != "\u{001B}[0m" }) {
                    #expect(sgrs.last == "\u{001B}[0m", Comment(rawValue: line.debugDescription))
                }
                let oscs = line.ranges(of: /\u{1B}\]8;;[^\u{1B}\u{07}]*(\u{1B}\\|\u{07})/).map { String(line[$0]) }
                if oscs.contains(where: { $0 != TerminalCanvas.linkClose }) {
                    #expect(oscs.last == TerminalCanvas.linkClose, Comment(rawValue: line.debugDescription))
                }
            }
        }
    }

    @Test("Cell truncation shows the same text as string truncation")
    func cellTruncate() {
        var rng = SplitMix64(seed: 7)
        for _ in 0..<500 {
            let canvas = TerminalCanvas(width: 60, height: 1)
            canvas.write(randomStyledRun(&rng) + randomStyledRun(&rng), at: Point(column: Int.random(in: 0..<5, using: &rng), row: 0))
            let row = canvas.cellRows()[0]
            let line = TerminalCanvas.emit(row[...])
            let limit = Int.random(in: 0...20, using: &rng)
            let byCells = TerminalCanvas.emit(FrameDiff.truncate(row, toColumns: limit)[...])
            let byString = TextMetrics.truncate(line, toColumns: limit)
            #expect(TextMetrics.stripANSI(byCells) == TextMetrics.stripANSI(byString))
        }
    }
}

// MARK: - Screen diff

/// Just enough of a VT100 to replay the renderer's output: absolute cursor
/// moves, erase to end of line / screen, SGR and OSC 8 state, scroll margins
/// with line feed and reverse index, and wide glyphs occupying two cells.
private struct ScreenEmulator {
    struct Cell: Equatable { var glyph: String; var style: String; var link: String }
    static let blank = Cell(glyph: " ", style: "", link: "")

    var cells: [[Cell]]
    var row = 0, column = 0
    var top = 0, bottom: Int
    var style = "", link = ""
    var scrolled = 0

    init(rows: Int, columns: Int) {
        cells = Array(repeating: Array(repeating: Self.blank, count: columns), count: rows)
        bottom = rows - 1
    }

    init(rows: Int, columns: Int, showing frame: [[TerminalCell]]) {
        self.init(rows: rows, columns: columns)
        for (r, line) in frame.enumerated() { paint(line, atRow: r) }
    }

    mutating func paint(_ line: [TerminalCell], atRow r: Int) {
        var c = 0
        for cell in line {
            cells[r][c] = Cell(glyph: cell.glyph, style: cell.style, link: cell.link)
            c += 1
        }
    }

    mutating func feed(_ output: String) {
        let chars = Array(output)
        var i = 0
        func number(_ s: String, default d: Int) -> Int { Int(s) ?? d }
        while i < chars.count {
            let ch = chars[i]
            if ch == "\u{001B}" {
                i += 1
                guard i < chars.count else { return }
                if chars[i] == "[" {
                    var params = ""
                    i += 1
                    while i < chars.count, chars[i].isNumber || chars[i] == ";" || chars[i] == "?" { params.append(chars[i]); i += 1 }
                    let final = chars[i]; i += 1
                    let parts = params.split(separator: ";", omittingEmptySubsequences: false).map(String.init)
                    switch final {
                    case "H":
                        // Like a terminal, the cursor is clamped to the screen.
                        row = min(cells.count - 1, number(parts.first ?? "", default: 1) - 1)
                        column = min(cells[row].count - 1, number(parts.count > 1 ? parts[1] : "", default: 1) - 1)
                    case "K":
                        for c in column..<max(column, cells[row].count) { cells[row][c] = Self.blank }
                    case "J":
                        precondition(params == "0" || params == "2" || params.isEmpty)
                        if params == "2" {
                            for r in cells.indices { for c in cells[r].indices { cells[r][c] = Self.blank } }
                        } else {
                            for c in column..<cells[row].count { cells[row][c] = Self.blank }
                            for r in (row + 1)..<cells.count { for c in cells[r].indices { cells[r][c] = Self.blank } }
                        }
                    case "r":
                        if params.isEmpty { top = 0; bottom = cells.count - 1 }
                        else { top = number(parts[0], default: 1) - 1; bottom = number(parts[1], default: cells.count) - 1 }
                        row = 0; column = 0
                    case "m":
                        let seq = "\u{001B}[" + params + "m"
                        if seq == "\u{001B}[0m" { style = "" } else { style += seq }
                    case "l", "h":
                        break // cursor visibility, ignored
                    default:
                        Issue.record("unexpected CSI \(params)\(final)")
                    }
                } else if chars[i] == "]" {
                    var seq = "\u{001B}]"
                    i += 1
                    while i < chars.count {
                        let c = chars[i]; seq.append(c); i += 1
                        if c == "\u{0007}" { break }
                        if c == "\u{001B}" { if i < chars.count, chars[i] == "\\" { seq.append(chars[i]); i += 1 }; break }
                    }
                    link = (seq == TerminalCanvas.linkClose) ? "" : seq
                } else if chars[i] == "M" {
                    i += 1
                    if row == top {
                        for r in stride(from: bottom, to: top, by: -1) { cells[r] = cells[r - 1] }
                        cells[top] = Array(repeating: Self.blank, count: cells[top].count)
                        scrolled += 1
                    } else if row > 0 { row -= 1 }
                } else {
                    Issue.record("unexpected ESC \(chars[i])")
                    i += 1
                }
            } else if ch == "\n" {
                i += 1
                if row == bottom {
                    for r in top..<bottom { cells[r] = cells[r + 1] }
                    cells[bottom] = Array(repeating: Self.blank, count: cells[bottom].count)
                    scrolled += 1
                } else if row < cells.count - 1 { row += 1 }
            } else if ch == "\r" {
                i += 1; column = 0
            } else {
                i += 1
                var glyph = String(ch)
                // Zero-width marks compose onto the previous cell.
                let w = TextMetrics.width(of: ch)
                if w == 0 {
                    if column > 0 { cells[row][column - 1].glyph += glyph }
                    continue
                }
                // A following lone mark (emitted after a style change) also composes.
                while i < chars.count, chars[i] != "\u{001B}", TextMetrics.width(of: chars[i]) == 0 {
                    glyph += String(chars[i]); i += 1
                }
                cells[row][column] = Cell(glyph: glyph, style: style, link: link)
                if w == 2, column + 1 < cells[row].count { cells[row][column + 1] = Cell(glyph: "", style: "", link: "") }
                column += w
            }
        }
    }

    /// Describes the first row that doesn't show `frame`, or `nil`.
    ///
    /// Rows are compared by their visible text and by the style and link of
    /// every column that carries a glyph. A lone combining mark that a frame
    /// keeps in a wide glyph's continuation cell composes onto that glyph on
    /// screen, so the text is compared as one string and such mark-only cells
    /// don't take part in the attribute comparison.
    func mismatch(_ frame: [[TerminalCell]]) -> String? {
        func isMarkOnly(_ glyph: String) -> Bool { glyph.first.map { TextMetrics.width(of: $0) == 0 } ?? false }
        for r in cells.indices {
            let line = r < frame.count ? frame[r] : []
            let expectedCells: [Cell] = (0..<cells[r].count).map { c in
                guard c < line.count else { return Self.blank }
                let cell = line[c]
                return cell.written ? Cell(glyph: cell.glyph, style: cell.style, link: cell.link) : Self.blank
            }
            let actual = cells[r]
            if actual.map(\.glyph).joined() != expectedCells.map(\.glyph).joined() {
                return "row \(r) text: \(actual.map(\.glyph).joined().debugDescription) vs \(expectedCells.map(\.glyph).joined().debugDescription)"
            }
            for c in actual.indices where !isMarkOnly(expectedCells[c].glyph) && !expectedCells[c].glyph.isEmpty {
                if actual[c].style != expectedCells[c].style || actual[c].link != expectedCells[c].link {
                    return "row \(r) col \(c) attrs: \(actual[c]) vs \(expectedCells[c])"
                }
            }
        }
        return nil
    }
}

@Suite("Cell Diff Equivalence")
struct CellDiffEquivalenceTests {
    private static let screenColumns = 48

    private func randomFrame(_ rng: inout SplitMix64, rows: Int) -> [[TerminalCell]] {
        let canvas = TerminalCanvas(width: Self.screenColumns, height: rows)
        // One write per row (see `roundTrip` on why writes don't overlap).
        for row in 0..<rows where Bool.random(using: &rng) {
            var text = randomStyledRun(&rng)
            if Bool.random(using: &rng) { text += randomStyledRun(&rng) }
            canvas.write(text, at: Point(column: Int.random(in: 0..<20, using: &rng), row: row))
        }
        // Clipped to the screen width the way the renderer clips every frame.
        var frame = canvas.cellRows().map { FrameDiff.truncate($0, toColumns: Self.screenColumns) }
        // Occasionally drop trailing rows so the frame is shorter than the screen.
        if Int.random(in: 0..<4, using: &rng) == 0 { frame.removeLast(Int.random(in: 0..<rows, using: &rng)) }
        return frame
    }

    private func check(old: [[TerminalCell]]?, new: [[TerminalCell]], rows: Int) -> (ok: Bool, output: String, scrolled: Bool) {
        var screen = old.map { ScreenEmulator(rows: rows + 1, columns: Self.screenColumns, showing: $0) }
            ?? ScreenEmulator(rows: rows + 1, columns: Self.screenColumns)
        let output = FrameDiff.fullScreenUpdate(fromRows: old, toRows: new, preamble: "")
        screen.feed(output)
        let mismatch = screen.mismatch(new)
        return (mismatch == nil, (mismatch ?? "") + " :: " + output, screen.scrolled > 0)
    }

    @Test("Replaying the diff over the old screen produces the new frame")
    func arbitraryFrames() {
        var rng = SplitMix64(seed: 8)
        for _ in 0..<400 {
            let rows = Int.random(in: 3...14, using: &rng)
            let old = randomFrame(&rng, rows: rows)
            let new = randomFrame(&rng, rows: rows)
            let result = check(old: old, new: new, rows: rows)
            #expect(result.ok, Comment(rawValue: result.output.debugDescription))
            let first = check(old: nil, new: new, rows: rows)
            #expect(first.ok, Comment(rawValue: first.output.debugDescription))
            // A frame diffed against itself needs no cell writes at all.
            let same = FrameDiff.fullScreenUpdate(fromRows: new, toRows: new, preamble: "")
            #expect(same == "\u{001B}[\(new.count + 1);1H")
        }
    }

    @Test("A scrolled frame is reproduced through the terminal's scroll region")
    func scrolledFrames() {
        var rng = SplitMix64(seed: 9)
        var hardwareScrolls = 0
        for _ in 0..<400 {
            let rows = Int.random(in: 4...16, using: &rng)
            // Distinct rows, like a list: "row N" plus a bar column that changes.
            func frame(offset: Int, thumb: Int) -> [[TerminalCell]] {
                let canvas = TerminalCanvas(width: 30, height: rows)
                for r in 0..<rows {
                    let style = sampleStyles[abs(r + offset) % sampleStyles.count]
                    canvas.write(style.ansiPrefix + "row \(r + offset) 日本" + "\u{001B}[0m", at: Point(column: 0, row: r))
                    let bar = TextStyle(foreground: r == thumb ? .cyan : .eightBit(238)).ansiPrefix + (r == thumb ? "▀" : "█") + "\u{001B}[0m"
                    canvas.write(bar, at: Point(column: 25, row: r))
                }
                return canvas.cellRows()
            }
            let offset = Int.random(in: 0...100, using: &rng)
            let shift = Int.random(in: -(rows - 1)...(rows - 1), using: &rng)
            let old = frame(offset: offset, thumb: Int.random(in: 0..<rows, using: &rng))
            var new = frame(offset: offset + shift, thumb: Int.random(in: 0..<rows, using: &rng))
            // Sometimes a header row stays put above the scrolled rows.
            if Bool.random(using: &rng), !new.isEmpty, !old.isEmpty { new[0] = old[0] }
            let result = check(old: old, new: new, rows: rows)
            #expect(result.ok, "shift=\(shift) rows=\(rows) output=\(result.output.debugDescription)")
            if result.scrolled { hardwareScrolls += 1 }
        }
        // The scroll-region path must actually have been exercised.
        #expect(hardwareScrolls > 100)
    }

    @Test("The cell diff and the line diff paint the same screen")
    func againstLineDiff() {
        var rng = SplitMix64(seed: 10)
        for _ in 0..<300 {
            let rows = Int.random(in: 3...12, using: &rng)
            let old = randomFrame(&rng, rows: rows)
            let new = randomFrame(&rng, rows: rows)
            var viaCells = ScreenEmulator(rows: rows + 1, columns: Self.screenColumns, showing: old)
            viaCells.feed(FrameDiff.fullScreenUpdate(fromRows: old, toRows: new, preamble: ""))
            var viaLines = ScreenEmulator(rows: rows + 1, columns: Self.screenColumns, showing: old)
            let oldFrame = Frame(lines: old.map { TerminalCanvas.emit($0[...]) })
            let newFrame = Frame(lines: new.map { TerminalCanvas.emit($0[...]) })
            viaLines.feed(FrameDiff.fullScreenUpdate(from: oldFrame, to: newFrame))
            #expect(viaCells.cells == viaLines.cells)
        }
    }
}
