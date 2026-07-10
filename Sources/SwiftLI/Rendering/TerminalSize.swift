//
//  TerminalSize.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/07.
//

import Foundation

/// The size of the controlling terminal, measured in character cells.
///
/// Use ``TerminalSize/current`` to ask the terminal how many columns and rows
/// are currently available — for example, to size a ``Divider`` or
/// ``ProgressView`` to the full width of the window, or to wrap text:
///
/// ```swift
/// let width = TerminalSize.current.columns
/// ProgressView(value: 0.5, width: width - 8).render()
/// ```
///
/// ## How the size is resolved
///
/// `current` tries each source in order and returns the first that yields a
/// positive column count:
///
/// 1. `ioctl(TIOCGWINSZ)` on stdout, then stderr, then stdin — the authoritative
///    kernel value, updated live as the window is resized.
/// 2. The `COLUMNS` / `LINES` environment variables.
/// 3. ``TerminalSize/default`` (80 × 24), used when output is piped to a file
///    or another program and there is no attached terminal.
///
/// > Note: In a reactive ``CLIApp``, the runtime re-renders on `SIGWINCH`
/// > (terminal resize), so reading `TerminalSize.current` inside `body` always
/// > reflects the latest dimensions.
public struct TerminalSize: Equatable, Sendable {
    /// Number of character columns (the count of characters that fit on one row).
    public let columns: Int
    /// Number of character rows (lines) that fit on screen.
    public let rows: Int

    public init(columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
    }

    /// The fallback size (80 columns × 24 rows) used when no terminal is attached.
    public static let `default` = TerminalSize(columns: 80, rows: 24)

    /// The current size of the controlling terminal.
    ///
    /// Recomputed on every access, so it reflects the latest window dimensions.
    /// Falls back to environment variables and then ``default`` when there is no
    /// attached terminal (e.g. when output is redirected).
    public static var current: TerminalSize {
        for fd in [STDOUT_FILENO, STDERR_FILENO, STDIN_FILENO] {
            if let size = ioctlSize(fd) { return size }
        }
        if let size = environmentSize() { return size }
        return .default
    }

    // MARK: - Sources

    /// Queries the kernel for the window size of `fd` via `ioctl(TIOCGWINSZ)`.
    /// Returns `nil` when `fd` is not a terminal or reports a zero width.
    private static func ioctlSize(_ fd: Int32) -> TerminalSize? {
        var ws = winsize()
        guard ioctl(fd, UInt(TIOCGWINSZ), &ws) == 0 else { return nil }
        guard ws.ws_col > 0 else { return nil }
        return TerminalSize(columns: Int(ws.ws_col), rows: Int(ws.ws_row))
    }

    /// Reads the size from the `COLUMNS` / `LINES` environment variables.
    /// Returns `nil` when `COLUMNS` is missing or non-positive.
    private static func environmentSize() -> TerminalSize? {
        let env = ProcessInfo.processInfo.environment
        guard let colString = env["COLUMNS"], let cols = Int(colString), cols > 0 else {
            return nil
        }
        let rows = env["LINES"].flatMap(Int.init) ?? TerminalSize.default.rows
        return TerminalSize(columns: cols, rows: rows)
    }
}
