//
//  Frame.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/06.
//

/// A fully laid-out snapshot of a view tree: the exact lines that will appear
/// in the terminal.
///
/// A `Frame` is the final product of the intermediate representation
/// pipeline. Because it is a plain value, two consecutive frames can be
/// compared with ``FrameDiff`` to find out exactly which lines changed.
public struct Frame: Equatable, Sendable {
    /// Raw escape output emitted before the grid content (e.g. a screen-clear
    /// sequence carried by ``RenderNode/raw(_:)``).
    public var preamble: String

    /// The rendered rows, top to bottom, with trailing blanks trimmed.
    public var lines: [String]

    /// Creates a new frame with optional preamble escape sequences and rendered lines.
    ///
    /// - Parameters:
    ///   - preamble: Raw escape output to emit before the grid content. Defaults to an empty string.
    ///   - lines: The rendered rows of the frame, top to bottom, with trailing blanks trimmed.
    public init(preamble: String = "", lines: [String]) {
        self.preamble = preamble
        self.lines = lines
    }

    /// The rendered rows as cells — the same content as ``lines`` in
    /// structured form, which the full-screen renderer diffs cell by cell.
    /// `nil` for a frame assembled directly from strings.
    var rows: [[TerminalCell]]? = nil

    /// A frame with no content.
    public static let empty = Frame(lines: [])

    /// Two frames are equal when they display the same lines; the cell rows
    /// are a derived view of those lines and don't take part.
    public static func == (lhs: Frame, rhs: Frame) -> Bool {
        lhs.preamble == rhs.preamble && lhs.lines == rhs.lines
    }
}

/// Computes the minimal ANSI output needed to turn one ``Frame`` into another.
///
/// Comparing the intermediate representation of two consecutive renders makes
/// it possible to rewrite only the lines that actually changed, instead of
/// erasing and reprinting the whole body on every update. This is what keeps
/// live views (progress bars, spinners, reactive apps) flicker-free.
public enum FrameDiff {

    private static let eraseLine = "\u{001B}[2K"

    /// The number of physical terminal rows a logical line occupies at the
    /// given column width — i.e. how many rows it wraps onto.
    ///
    /// A line that fits (or is empty) is one row; a line exactly `columns` wide
    /// is still one row (terminals defer the wrap until the next character).
    static func physicalRows(_ line: String, columns: Int) -> Int {
        guard columns > 0 else { return 1 }
        let width = TextMetrics.visibleWidth(TextMetrics.stripANSI(line))
        if width <= columns { return 1 }
        return (width + columns - 1) / columns
    }

    /// Redraws `new` over `old` from scratch, used when the terminal width has
    /// changed since the previous frame.
    ///
    /// On resize the terminal reflows the already-printed block, so the per-line
    /// cursor arithmetic of ``inlineUpdate(from:to:)`` no longer lines up. This
    /// instead walks up by the *physical* row count the old block occupies at
    /// the current width, erases everything below, and repaints — which stays
    /// correct no matter how the block was rewrapped.
    static func inlineRepaint(from old: Frame, to new: Frame, columns: Int) -> String {
        var out = new.preamble
        let oldRows = old.lines.reduce(0) { $0 + physicalRows($1, columns: columns) }
        if oldRows > 0 { out += "\u{001B}[\(oldRows)A" }
        out += "\r\u{001B}[0J" // to column 0, then erase to end of screen
        for line in new.lines { out += line + "\n" }
        return out
    }

    /// Returns the ANSI string that redraws `new` over `old` in **inline** mode.
    ///
    /// Assumes the cursor rests at column 0 on the line just below the old
    /// frame (where the previous render left it), and leaves it at the
    /// equivalent position below the new frame. Unchanged lines are skipped
    /// with a cursor movement; only changed lines are erased and rewritten.
    public static func inlineUpdate(from old: Frame?, to new: Frame) -> String {
        var out = new.preamble

        guard let old, !old.lines.isEmpty else {
            // First render (or nothing to replace): print everything.
            for line in new.lines { out += line + "\n" }
            return out
        }

        // Move up to the first line of the previous frame.
        out += "\u{001B}[\(old.lines.count)A"

        for (i, line) in new.lines.enumerated() {
            if i < old.lines.count && old.lines[i] == line {
                out += "\u{001B}[1B" // unchanged — just step over it
            } else {
                out += "\r" + eraseLine + line + "\n"
            }
        }

        // The old frame had extra lines below the new content: blank them
        // out, then move the cursor back up to just below the new frame.
        if old.lines.count > new.lines.count {
            let extra = old.lines.count - new.lines.count
            for _ in 0..<extra { out += eraseLine + "\u{001B}[1B" }
            out += "\u{001B}[\(extra)A"
        }
        return out
    }

    /// Returns the ANSI string that redraws `new` over `old` in **full-screen**
    /// mode, using absolute cursor positioning from the top-left corner.
    ///
    /// Only lines that differ from the previous frame are rewritten; any
    /// leftover content below the new frame is cleared.
    public static func fullScreenUpdate(from old: Frame?, to new: Frame) -> String {
        var out = new.preamble
        let oldLines = old?.lines ?? []

        for (i, line) in new.lines.enumerated() {
            if i < oldLines.count && oldLines[i] == line { continue }
            // Write the new content over the old first, then erase only
            // whatever's left dangling past it — not the other way around.
            // Erasing the whole line *before* writing (as this used to)
            // leaves a real gap, blank-then-drawn, between the two steps;
            // even though both are queued in the same write(), a terminal
            // that paints incrementally as it parses the stream can show
            // that gap as a momentary flash — most visible on exactly the
            // row being actively typed into (e.g. finishing IME composition
            // committing a character). Writing first overwrites every cell
            // the new content covers in place, with no blank state ever
            // existing for it; the trailing erase only clears a *shorter*
            // replacement's leftover tail, which is never the cell just typed.
            out += "\u{001B}[\(i + 1);1H" + line + "\u{001B}[K"
        }

        // Park the cursor below the frame and clear any stale content there.
        out += "\u{001B}[\(new.lines.count + 1);1H"
        if oldLines.count > new.lines.count || old == nil {
            out += "\u{001B}[0J"
        }
        return out
    }
}

// MARK: - Cell-level full-screen diff

extension FrameDiff {

    /// Clips a row of cells to `limit` columns, the cell-level twin of
    /// ``TextMetrics/truncate(_:toColumns:)``: a wide glyph that would straddle
    /// the limit is dropped rather than split.
    static func truncate(_ row: [TerminalCell], toColumns limit: Int) -> [TerminalCell] {
        if limit <= 0 { return [] }
        var width = 0
        var count = 0
        for cell in row {
            let w = Int(cell.width)
            if width + w > limit { break }
            width += w
            count += 1
        }
        return count == row.count ? row : Array(row.prefix(count))
    }

    /// Returns the ANSI string that redraws `new` over `old` in **full-screen**
    /// mode, working from the frames' cells rather than their lines.
    ///
    /// Produces the same screen as ``fullScreenUpdate(from:to:)`` with far less
    /// output: only the cells that differ are rewritten (a changed scrollbar
    /// cell no longer costs its whole row), and when the new frame is the old
    /// one shifted up or down — the signature of scrolling — the terminal is
    /// asked to move those rows itself inside a scroll region, so only the
    /// rows that actually entered the viewport are painted.
    static func fullScreenUpdate(fromRows old: [[TerminalCell]]?, toRows new: [[TerminalCell]], preamble: String) -> String {
        var out = preamble
        // What the screen holds right now, row by row; refined as output is
        // emitted so every later step diffs against the true screen state.
        var expected = old ?? []

        if let old, let shift = hardwareScroll(from: old, to: new) {
            // Scroll the region with the terminal's own line feed / reverse
            // index at its margins — the VT100 primitives every terminal
            // implements — after resetting attributes so the vacated rows are
            // filled with the default background.
            out += "\u{001B}[0m\u{001B}[\(shift.top + 1);\(shift.bottom + 1)r"
            if shift.by > 0 {
                out += "\u{001B}[\(shift.bottom + 1);1H" + String(repeating: "\n", count: shift.by)
            } else {
                out += "\u{001B}[\(shift.top + 1);1H" + String(repeating: "\u{001B}M", count: -shift.by)
            }
            out += "\u{001B}[r"

            if expected.count <= shift.bottom {
                expected.append(contentsOf: Array(repeating: [], count: shift.bottom + 1 - expected.count))
            }
            let before = expected
            for row in shift.top...shift.bottom {
                let source = row + shift.by
                expected[row] = (source >= shift.top && source <= shift.bottom) ? before[source] : []
            }
        }

        for (i, row) in new.enumerated() {
            let current = i < expected.count ? expected[i] : []
            if current == row { continue }
            out += rowPatch(row: i, expected: current, new: row)
        }

        // Park the cursor below the frame and clear any stale content there.
        let oldCount = old?.count ?? 0
        out += "\u{001B}[\(new.count + 1);1H"
        if oldCount > new.count || old == nil {
            out += "\u{001B}[0J"
        }
        return out
    }

    /// Looks for a vertical shift that maps most of the rows that changed onto
    /// rows of the old frame: `new[r] == old[r + by]` for the rows of
    /// `top...bottom` (`by > 0` scrolls content up, `< 0` down).
    ///
    /// Rows are compared by their glyphs only, so a row that merely changed
    /// colour (a scrollbar thumb passing, a selection highlight) still counts
    /// as shifted — the cell diff that follows repaints the colour. The shift
    /// is only worth taking when at least three changed rows line up and they
    /// make up at least half of the rows the region would move.
    static func hardwareScroll(from old: [[TerminalCell]], to new: [[TerminalCell]]) -> (by: Int, top: Int, bottom: Int)? {
        let count = Swift.min(old.count, new.count)
        guard count >= 3 else { return nil }

        func glyphHash(_ row: [TerminalCell]) -> Int {
            var hasher = Hasher()
            for cell in row { hasher.combine(cell.glyph) }
            return hasher.finalize()
        }
        let oldHashes = old.prefix(count).map(glyphHash)
        let newHashes = new.prefix(count).map(glyphHash)
        // Only rows that differ in place and have content can justify a shift;
        // rows that already match (or are blank) would match trivially.
        let candidate = (0..<count).map { !new[$0].isEmpty && new[$0] != old[$0] }

        var best: (by: Int, matches: Int, first: Int, last: Int)?
        for magnitude in 1..<count {
            for by in [magnitude, -magnitude] {
                var matches = 0
                var first = Int.max
                var last = Int.min
                for r in 0..<count where candidate[r] {
                    let source = r + by
                    guard source >= 0, source < count, newHashes[r] == oldHashes[source] else { continue }
                    matches += 1
                    first = Swift.min(first, r)
                    last = Swift.max(last, r)
                }
                if matches > (best?.matches ?? 0) {
                    best = (by, matches, first, last)
                }
            }
        }

        guard let best, best.matches >= 3 else { return nil }
        // The region must cover each matched row and the row it came from.
        let top = best.by > 0 ? best.first : best.first + best.by
        let bottom = best.by > 0 ? best.last + best.by : best.last
        let moved = bottom - top + 1 - abs(best.by)
        guard bottom > top, best.matches * 2 >= moved else { return nil }
        return (best.by, top, bottom)
    }

    /// The output that turns the screen row `expected` into `new`: each run of
    /// differing cells (runs closer than eight cells are merged) is rewritten
    /// in place, and a tail the new row no longer covers is erased.
    static func rowPatch(row: Int, expected: [TerminalCell], new: [TerminalCell]) -> String {
        let total = Swift.max(expected.count, new.count)
        let common = Swift.min(expected.count, new.count)
        @inline(__always) func differs(_ c: Int) -> Bool {
            c >= common || expected[c] != new[c]
        }

        var out = ""
        var c = 0
        while c < total {
            guard differs(c) else { c += 1; continue }
            var start = c
            var end = c
            // Extend over nearby differences so one cursor move covers them.
            var probe = c + 1
            var gap = 0
            while probe < total {
                if differs(probe) {
                    end = probe
                    gap = 0
                } else {
                    gap += 1
                    if gap >= 8 { break }
                }
                probe += 1
            }
            c = end + 1

            // Never start inside a wide glyph: back up onto its first column.
            while start > 0,
                  (start < new.count && new[start].written && new[start].width == 0)
                    || (start < expected.count && expected[start].written && expected[start].width == 0) {
                start -= 1
            }

            out += "\u{001B}[\(row + 1);\(start + 1)H"
            let stop = Swift.min(end + 1, new.count)
            if start < stop {
                out += TerminalCanvas.emit(new[start..<stop])
            }
            if end >= new.count {
                // The old row extended past the new content: erase the rest.
                out += "\u{001B}[K"
            }
        }
        return out
    }
}
