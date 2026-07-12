//
//  KeyEvent.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/07.
//

/// A single decoded keyboard event.
///
/// Raw terminal input (bytes on stdin) is parsed by ``KeyDecoder`` into a
/// stream of `KeyEvent`s that the reactive runtime routes to the focused
/// ``TextField``.
public enum KeyEvent: Equatable, Sendable {
    /// A printable character was typed.
    case character(Character)
    /// Backspace / delete-backward (`0x7F` or `0x08`).
    case backspace
    /// Forward delete (`ESC [ 3 ~` or Ctrl-D).
    case delete
    /// Delete from the cursor to the start of the line (Ctrl-U).
    case deleteToStart
    /// Delete from the cursor to the end of the line (Ctrl-K).
    case deleteToEnd
    /// Delete the word immediately before the cursor (Ctrl-W).
    case deleteWordBackward
    /// Left arrow — move the cursor one column left.
    case left
    /// Right arrow — move the cursor one column right.
    case right
    /// Up arrow.
    case up
    /// Down arrow.
    case down
    /// Home — move the cursor to the start of the field.
    case home
    /// End — move the cursor to the end of the field.
    case end
    /// Return / Enter.
    case enter
    /// Tab — advance focus to the next field.
    case tab
    /// Shift-Tab — move focus to the previous field.
    case backTab
    /// Escape key (a lone `ESC`).
    case escape
    /// Ctrl-C — request application shutdown.
    case interrupt
    /// A pointing-device event (click, drag, scroll wheel), decoded from the
    /// same input stream as keystrokes. See ``MouseEvent``.
    case mouse(MouseEvent)
    /// A cursor-position report (`ESC [ row ; col R`, converted to 0-based) —
    /// the terminal's answer to a `CSI 6n` query, not user input. The runtime
    /// uses it to locate an inline frame on screen for mouse routing.
    case cursorPosition(row: Int, column: Int)
}

/// Applies an editing command to a text buffer with a cursor, as a pure
/// function.
///
/// The engine performs the *what* of editing (insertion, deletion, cursor
/// movement); a ``TextInputKeymap`` decides the *which key*. Keeping it free of
/// any I/O makes the whole line-editing behaviour unit-testable without a
/// terminal. This type is internal — text controls drive it for you.
enum TextFieldEditor {

    /// Number of spaces inserted (or removed) by one indent / dedent.
    static let indentWidth = 4

    /// The result of applying a command: the new text and new cursor index.
    struct Result: Equatable, Sendable {
        var text: String
        /// Cursor position as a character offset in `0...text.count`.
        var cursor: Int
    }

    /// Returns the buffer and cursor after applying `command`.
    ///
    /// The cursor is measured in **characters** (grapheme-agnostic `Character`
    /// units), clamped to `0...text.count`. Non-editing commands (`.submit`,
    /// `.focusNext`, `.ignore`, …) leave the text and cursor unchanged.
    ///
    /// - Parameters:
    ///   - command: The editing command to perform.
    ///   - text: The current field contents.
    ///   - cursor: The current cursor character offset.
    static func apply(_ command: TextEditCommand, to text: String, cursor: Int) -> Result {
        var chars = Array(text)
        var c = Swift.min(Swift.max(cursor, 0), chars.count)

        switch command {
        case .insert(let ch):
            chars.insert(ch, at: c)
            c += 1
        case .newline:
            chars.insert("\n", at: c)
            c += 1
        case .deleteBackward:
            if c > 0 {
                chars.remove(at: c - 1)
                c -= 1
            }
        case .deleteForward:
            if c < chars.count {
                chars.remove(at: c)
            }
        case .deleteToLineStart:
            // Kill from the cursor back to the start of the current line.
            let start = lineStart(chars, c)
            if start < c {
                chars.removeSubrange(start..<c)
                c = start
            }
        case .deleteToLineEnd:
            // Kill from the cursor to the end of the current line.
            let end = lineEnd(chars, c)
            if c < end {
                chars.removeSubrange(c..<end)
            }
        case .deleteWordBackward:
            // Skip spaces just before the cursor, then delete the word.
            var start = c
            while start > 0 && chars[start - 1] == " " { start -= 1 }
            while start > 0 && chars[start - 1] != " " { start -= 1 }
            if start < c {
                chars.removeSubrange(start..<c)
                c = start
            }
        case .moveLeft:
            if c > 0 { c -= 1 }
        case .moveRight:
            if c < chars.count { c += 1 }
        case .moveToLineStart:
            c = lineStart(chars, c)
        case .moveToLineEnd:
            c = lineEnd(chars, c)
        case .moveUp:
            c = verticalMove(chars, from: c, up: true)
        case .moveDown:
            c = verticalMove(chars, from: c, up: false)
        case .indent:
            // Insert one indent's worth of spaces at the cursor.
            chars.insert(contentsOf: Array(repeating: " ", count: indentWidth), at: c)
            c += indentWidth
        case .dedent:
            // Remove up to one indent's worth of leading spaces on the line.
            let start = lineStart(chars, c)
            var removed = 0
            while removed < indentWidth && start + removed < chars.count && chars[start + removed] == " " {
                removed += 1
            }
            if removed > 0 {
                chars.removeSubrange(start..<(start + removed))
                c = Swift.max(start, c - removed)
            }
        case .submit, .focusNext, .focusPrevious, .cancel, .ignore:
            break
        }

        return Result(text: String(chars), cursor: c)
    }

    // MARK: - Line geometry (multi-line aware; degrades to no-ops on one line)

    /// Index of the first character of the line containing `c`.
    private static func lineStart(_ chars: [Character], _ c: Int) -> Int {
        var i = Swift.min(c, chars.count)
        while i > 0 && chars[i - 1] != "\n" { i -= 1 }
        return i
    }

    /// Index just past the last character of the line containing `c`
    /// (the position of the trailing `\n`, or the end of the text).
    private static func lineEnd(_ chars: [Character], _ c: Int) -> Int {
        var i = Swift.min(c, chars.count)
        while i < chars.count && chars[i] != "\n" { i += 1 }
        return i
    }

    /// Moves the cursor to the same column on the previous/next line, clamped to
    /// that line's length. Returns `c` unchanged when there is no such line.
    private static func verticalMove(_ chars: [Character], from c: Int, up: Bool) -> Int {
        let start = lineStart(chars, c)
        let column = c - start
        if up {
            guard start > 0 else { return c }          // already on the first line
            let prevEnd = start - 1                     // the '\n' ending the previous line
            let prevStart = lineStart(chars, prevEnd)
            return prevStart + Swift.min(column, prevEnd - prevStart)
        } else {
            let end = lineEnd(chars, c)
            guard end < chars.count else { return c }   // already on the last line
            let nextStart = end + 1
            let nextEnd = lineEnd(chars, nextStart)
            return nextStart + Swift.min(column, nextEnd - nextStart)
        }
    }
}
