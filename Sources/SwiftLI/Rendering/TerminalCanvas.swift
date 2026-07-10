//
//  TerminalCanvas.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2024/05/27.
//

import Foundation

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
public final class TerminalCanvas: @unchecked Sendable {

    // MARK: - Storage

    // Each cell stores the full "styled character" string (may include ANSI
    // escape sequences prefix + one visible character).
    private var cells: [[String]]
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
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.cells = Array(repeating: Array(repeating: " ", count: width), count: height)
    }

    // MARK: - Drawing

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

        // The ST-terminated close for an OSC 8 hyperlink.
        let linkClose = "\u{001B}]8;;\u{001B}\\"

        let segments = text.components(separatedBy: "\n")
        var row = origin.row
        // activeStyle tracks all currently-open SGR sequences so every visible
        // character in the run inherits the same style. activeLink separately
        // tracks an open OSC 8 hyperlink, so each linked cell can be emitted as
        // a self-contained clickable unit.
        var activeStyle = ""
        var activeLink = ""
        for segment in segments {
            guard row < height else { break }
            var col = origin.column

            var i = segment.startIndex
            while i < segment.endIndex {
                let ch = segment[i]
                if ch == "\u{001B}" {
                    var seq = ""
                    seq.append(ch)
                    i = segment.index(after: i)
                    if i < segment.endIndex, segment[i] == "]" {
                        // OSC (hyperlink): accumulate until BEL or ST (`\e\`).
                        seq.append(segment[i])
                        i = segment.index(after: i)
                        while i < segment.endIndex {
                            let ec = segment[i]
                            seq.append(ec)
                            i = segment.index(after: i)
                            if ec == "\u{0007}" { break }
                            if ec == "\u{001B}" {
                                if i < segment.endIndex, segment[i] == "\\" {
                                    seq.append(segment[i])
                                    i = segment.index(after: i)
                                }
                                break
                            }
                        }
                        // An empty-URI OSC 8 closes the link; anything else opens one.
                        activeLink = (seq == linkClose) ? "" : seq
                    } else {
                        // CSI (SGR): accumulate up to and including its 'm'.
                        while i < segment.endIndex {
                            let ec = segment[i]
                            seq.append(ec)
                            i = segment.index(after: i)
                            if ec == "m" { break }
                        }
                        if seq == "\u{001B}[0m" {
                            activeStyle = ""
                        } else {
                            activeStyle += seq
                        }
                    }
                } else {
                    // Advance the column by the glyph's visible width so wide
                    // glyphs (CJK, emoji) stay aligned with the layout, which
                    // also measures them as two columns.
                    let w = TextMetrics.width(of: ch)
                    if w == 0 {
                        // A lone combining / zero-width mark composes onto the
                        // previous cell rather than consuming a column.
                        if col > 0, col - 1 < width {
                            cells[row][col - 1] += String(ch)
                        }
                    } else {
                        if col < width {
                            // A linked cell is wrapped in its own OSC 8 open/close
                            // so it stays clickable on its own and never leaks the
                            // link onto later cells.
                            if activeLink.isEmpty {
                                cells[row][col] = activeStyle + String(ch) + "\u{001B}[0m"
                            } else {
                                cells[row][col] = activeLink + activeStyle + String(ch) + "\u{001B}[0m" + linkClose
                            }
                        }
                        // A wide glyph owns the next cell too; blank it so the
                        // real character at `col + w` is not overwritten.
                        if w >= 2, col + 1 < width {
                            cells[row][col + 1] = ""
                        }
                        col += w
                    }
                    i = segment.index(after: i)
                }
            }
            row += 1
        }
    }

    /// Expands the canvas to fit `rect` if needed, filling new cells with spaces.
    public func expand(toFit rect: Rect) {
        lock.lock()
        defer { lock.unlock() }

        let neededWidth  = rect.maxColumn
        let neededHeight = rect.maxRow

        if neededHeight > height {
            let newRows = Array(repeating: Array(repeating: " ", count: Swift.max(width, neededWidth)), count: neededHeight - height)
            cells.append(contentsOf: newRows)
            height = neededHeight
        }
        if neededWidth > width {
            for r in 0..<height {
                let extra = neededWidth - cells[r].count
                if extra > 0 {
                    cells[r].append(contentsOf: Array(repeating: " ", count: extra))
                }
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
        lock.lock()
        let snapshot = cells
        lock.unlock()

        for row in snapshot {
            print(_trimTrailingSpaces(row.joined()))
        }
    }

    // MARK: - Helpers

    /// Returns the canvas rows as an array of strings, one per row, with
    /// trailing plain spaces trimmed.
    ///
    /// This is the bridge from the mutable canvas to an immutable ``Frame``.
    public func lines() -> [String] {
        lock.lock()
        let snapshot = cells
        lock.unlock()
        return snapshot.map { _trimTrailingSpaces($0.joined()) }
    }

    /// Returns the rendered content as a plain `String` (useful for testing).
    /// Trailing spaces on each row are trimmed.
    public func toString() -> String {
        lines().joined(separator: "\n")
    }

    /// Strips trailing plain space characters from a string.
    /// ANSI-styled characters at the end are preserved.
    private func _trimTrailingSpaces(_ s: String) -> String {
        var result = s
        while result.hasSuffix(" ") {
            result.removeLast()
        }
        return result
    }
}
