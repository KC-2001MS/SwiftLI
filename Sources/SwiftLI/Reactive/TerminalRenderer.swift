//
//  TerminalRenderer.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2024/05/27.
//

import Foundation

/// Manages terminal output for the reactive rendering system.
///
/// `TerminalRenderer` handles cursor positioning and screen management using
/// ANSI escape sequences. Instead of clearing the entire screen on each update
/// (which causes visible flicker), it moves the cursor to the top-left corner
/// and overwrites content in-place, then clears any leftover lines below.
///
/// This approach mirrors how terminal applications like `top` and `htop`
/// achieve smooth, flicker-free updates.
public final class TerminalRenderer: Sendable {

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

        /// Move the cursor to a specific position (1-indexed row and column).
        static func moveTo(row: Int, col: Int) -> String {
            "\u{001B}[\(row);\(col)H"
        }
    }

    public init() {}

    // MARK: - Public API

    /// Prepares the terminal for reactive rendering.
    ///
    /// Call this once before the first render. It clears the screen and moves
    /// the cursor to the top-left corner.
    public func setup() {
        print(ANSICode.clearScreen, terminator: "")
        print(ANSICode.cursorHome, terminator: "")
        fflush(stdout)
    }

    /// Renders a view tree in-place without clearing the entire screen.
    ///
    /// The renderer:
    /// 1. Hides the cursor to prevent flicker.
    /// 2. Moves the cursor to the top-left (home position).
    /// 3. Calls `render()` on each view (which calls `print()` internally).
    /// 4. Clears any content remaining below the newly rendered content.
    /// 5. Shows the cursor again.
    ///
    /// - Parameter views: The array of views to render.
    public func renderFullScreen(_ views: [any View]) {
        // Suppress cursor movement flicker
        print(ANSICode.hideCursor, terminator: "")
        // Reposition to top-left rather than clearing the whole screen
        print(ANSICode.cursorHome, terminator: "")

        // Wrap all views in an implicit root VStack so they stack vertically
        let root = VStack(spacing: 0, children: views)
        root.render()

        // Erase any stale content below the current output
        print(ANSICode.clearToEnd, terminator: "")
        // Restore the cursor
        print(ANSICode.showCursor, terminator: "")

        // Force flush stdout so all output is visible immediately
        fflush(stdout)
    }

    /// Cleans up the terminal when the application exits.
    ///
    /// Ensures the cursor is visible, attributes are reset, and a final
    /// newline is appended so the shell prompt appears on its own line.
    public func teardown() {
        print(ANSICode.showCursor, terminator: "")
        print(ANSICode.reset, terminator: "")
        print("") // Final newline
        fflush(stdout)
    }
}
