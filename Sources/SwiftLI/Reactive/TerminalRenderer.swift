//
//  TerminalRenderer.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2024/05/27.
//

import Foundation

/// Manages terminal output for the reactive rendering system.
///
/// `TerminalRenderer` drives the intermediate-representation pipeline for
/// full-screen reactive apps. Each update lowers the view tree into a
/// ``Frame`` and compares it against the previously displayed frame with
/// ``FrameDiff``, rewriting only the lines that actually changed. Unchanged
/// lines are skipped entirely, which eliminates the flicker that a
/// clear-and-redraw approach would produce.
///
/// This mirrors how terminal applications like `top` and `htop` achieve
/// smooth, flicker-free updates.
public final class TerminalRenderer: @unchecked Sendable {

    // MARK: - ANSI Escape Codes

    /// ANSI escape sequences used for terminal control.
    public enum ANSICode {
        /// Move cursor to the home position (row 1, column 1).
        static let cursorHome      = "\u{001B}[H"
        /// Clear the entire visible screen.
        static let clearScreen     = "\u{001B}[2J"
        /// Clear from the cursor position to the end of the screen.
        static let clearToEnd      = "\u{001B}[0J"
        /// Hide the cursor (reduces flicker during re-draw).
        static let hideCursor      = "\u{001B}[?25l"
        /// Show the cursor.
        static let showCursor      = "\u{001B}[?25h"
        /// Reset all text attributes (color, bold, etc.).
        static let reset           = "\u{001B}[0m"
        /// Erase the current line and move cursor to column 1.
        static let eraseLine       = "\u{001B}[2K\r"
        /// Switch to the alternate screen buffer (saves the current screen).
        static let enterAltScreen  = "\u{001B}[?1049h"
        /// Leave the alternate screen buffer (restores the saved screen).
        static let leaveAltScreen  = "\u{001B}[?1049l"

        /// Move the cursor to a specific position (1-indexed row and column).
        static func moveTo(row: Int, col: Int) -> String {
            "\u{001B}[\(row);\(col)H"
        }
    }

    // MARK: - State

    /// The most recently displayed frame, or `nil` before the first render.
    private var previousFrame: Frame?
    /// The terminal width used for the previous frame, to detect a resize.
    private var previousColumns: Int?
    private let lock = NSLock()

    public init() {}

    // MARK: - Alternate screen session

    /// Enters the alternate screen buffer for a self-contained full-screen
    /// session, hiding the cursor and clearing to a blank canvas.
    ///
    /// The current screen (and the user's scrollback) is saved by the terminal
    /// and restored by ``endAlternateScreen()`` — exactly how `vim`, `htop`, and
    /// `less` take over the screen and hand it back untouched on exit. Because
    /// every frame is repainted from the home position, this is immune to the
    /// terminal reflowing content on resize.
    public func beginAlternateScreen() {
        lock.lock()
        previousFrame = nil
        previousColumns = nil
        lock.unlock()

        TerminalOutput.write(ANSICode.enterAltScreen + ANSICode.hideCursor + ANSICode.clearScreen + ANSICode.cursorHome)
    }

    /// Leaves the alternate screen buffer, restoring the screen that was visible
    /// before ``beginAlternateScreen()`` and showing the cursor again.
    public func endAlternateScreen() {
        TerminalOutput.write(ANSICode.reset + ANSICode.showCursor + ANSICode.leaveAltScreen)
    }

    // MARK: - Public API

    /// Prepares the terminal for reactive rendering.
    ///
    /// Call this once before the first render. It clears the screen, moves the
    /// cursor to the top-left corner, and resets any stored frame so the next
    /// render draws everything.
    public func setup() {
        lock.lock()
        previousFrame = nil
        lock.unlock()

        TerminalOutput.write(ANSICode.clearScreen + ANSICode.cursorHome)
    }

    /// Renders a view tree in-place, updating only the lines that changed.
    ///
    /// The renderer:
    /// 1. Hides the cursor to prevent flicker.
    /// 2. Lowers all views into a single ``RenderNode`` and lays it out.
    /// 3. Diffs the resulting ``Frame`` against the previous one and emits the
    ///    minimal escape sequence to reconcile them.
    /// 4. Shows the cursor again.
    ///
    /// - Parameter views: The array of views to render.
    public func renderFullScreen(_ views: [any View]) {
        // Wrap all views in an implicit root VStack so they stack vertically.
        let root = RenderNode.vstack(alignment: .leading, spacing: 0, children: views.map { $0.makeNode() })
        var frame = NodeLayout.frame(of: root)
        // Clip every line to the terminal width so nothing wraps onto a second
        // physical row, and cap the number of lines to the terminal height so
        // the frame never overflows and scrolls. Both would break the
        // line-addressed redraw.
        let size = TerminalSize.current
        let columns = size.columns
        // Full-screen draws each line with absolute cursor positioning (no
        // trailing newline), so writing the final column can't trigger a wrap —
        // the whole width is usable. Empty area below simply stays blank.
        frame.lines = frame.lines.map { TextMetrics.truncate($0, toColumns: columns) }
        if frame.lines.count > size.rows {
            frame.lines = Array(frame.lines.prefix(size.rows))
        }

        // Hold the lock across the whole compute-and-write. The frame bookkeeping
        // and the stdout write must be one atomic step: redraws can be triggered
        // from more than one thread (the key-input reader and the resize handler),
        // and if two of them interleaved their escape output the screen would tear
        // (a large page-scroll diff is big enough to interleave visibly).
        lock.lock()
        defer { lock.unlock() }

        // On a resize the whole canvas must be repainted from scratch, so drop
        // the previous frame and clear the screen before redrawing.
        let resized = previousColumns != nil && previousColumns != columns
        let baseline = resized ? nil : previousFrame
        let diff = FrameDiff.fullScreenUpdate(from: baseline, to: frame)
        previousFrame = frame
        previousColumns = columns

        // Emit the frame as a single write so it can't be split by another render.
        var output = ANSICode.hideCursor
        if resized { output += ANSICode.clearScreen }
        output += ANSICode.cursorHome + diff + ANSICode.showCursor
        TerminalOutput.write(output)
    }

    /// Cleans up the terminal when the application exits.
    ///
    /// Ensures the cursor is visible, attributes are reset, and a final
    /// newline is appended so the shell prompt appears on its own line.
    public func teardown() {
        TerminalOutput.write(ANSICode.showCursor + ANSICode.reset + "\n")
    }
}
