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
    /// Raw escape output emitted before the grid content (e.g. ``Clear``).
    public var preamble: String

    /// The rendered rows, top to bottom, with trailing blanks trimmed.
    public var lines: [String]

    public init(preamble: String = "", lines: [String]) {
        self.preamble = preamble
        self.lines = lines
    }

    /// A frame with no content.
    public static let empty = Frame(lines: [])
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
            out += "\u{001B}[\(i + 1);1H" + eraseLine + line
        }

        // Park the cursor below the frame and clear any stale content there.
        out += "\u{001B}[\(new.lines.count + 1);1H"
        if oldLines.count > new.lines.count || old == nil {
            out += "\u{001B}[0J"
        }
        return out
    }
}
