//
//  TextEditCommand.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/07.
//

/// A single editing action applied to a text buffer with a cursor.
///
/// Each in-editing behaviour is defined as one command — the internal
/// "modifier" for text input. A ``TextInputKeymap`` decides which ``KeyEvent``
/// produces which command, and ``TextFieldEditor`` performs it. Keeping the
/// action and the key binding separate lets a single-line ``TextField`` and a
/// multi-line ``TextEditor`` share one editing engine and differ only by keymap.
///
/// This type is an internal implementation detail and is not part of the public
/// API.
enum TextEditCommand: Equatable, Sendable {
    /// Insert a printable character at the cursor.
    case insert(Character)
    /// Insert a line break at the cursor (multi-line editors only).
    case newline
    /// Delete the character before the cursor.
    case deleteBackward
    /// Delete the character at the cursor.
    case deleteForward
    /// Delete from the cursor to the start of the current line.
    case deleteToLineStart
    /// Delete from the cursor to the end of the current line.
    case deleteToLineEnd
    /// Delete the word immediately before the cursor.
    case deleteWordBackward
    /// Insert one indent (spaces) at the cursor — a multi-line editor's Tab.
    case indent
    /// Remove one indent's worth of leading spaces from the current line.
    case dedent
    /// Move the cursor one column left / right.
    case moveLeft, moveRight
    /// Move the cursor to the same column on the previous / next line.
    case moveUp, moveDown
    /// Move the cursor to the start / end of the current line.
    case moveToLineStart, moveToLineEnd
    /// Invoke the field's submit action.
    case submit
    /// Advance / retreat focus to the next / previous field.
    case focusNext, focusPrevious
    /// Request cancellation (Ctrl-C); handled by the runtime, not the field.
    case cancel
    /// Do nothing.
    case ignore
}
