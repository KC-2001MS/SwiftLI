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

        let segments = text.components(separatedBy: "\n")
        var row = origin.row
        // activeStyle tracks all currently-open ANSI sequences so every
        // visible character in the run inherits the same style.
        var activeStyle = ""
        for segment in segments {
            guard row < height else { break }
            var col = origin.column

            var i = segment.startIndex
            while i < segment.endIndex {
                let ch = segment[i]
                if ch == "\u{001B}" {
                    // Accumulate the full escape sequence (ends at 'm').
                    var seq = ""
                    seq.append(ch)
                    i = segment.index(after: i)
                    while i < segment.endIndex {
                        let ec = segment[i]
                        seq.append(ec)
                        i = segment.index(after: i)
                        if ec == "m" { break }
                    }
                    // Reset clears accumulated style; any other sequence adds to it.
                    if seq == "\u{001B}[0m" {
                        activeStyle = ""
                    } else {
                        activeStyle += seq
                    }
                } else {
                    if col < width {
                        cells[row][col] = activeStyle + String(ch) + "\u{001B}[0m"
                    }
                    col += 1
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

    /// Returns the rendered content as a plain `String` (useful for testing).
    /// Trailing spaces on each row are trimmed.
    public func toString() -> String {
        lock.lock()
        let snapshot = cells
        lock.unlock()
        return snapshot.map { _trimTrailingSpaces($0.joined()) }.joined(separator: "\n")
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
