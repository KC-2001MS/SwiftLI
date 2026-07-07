//
//  TextInputKeymap.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/07.
//

/// Maps decoded key events to editing commands — the "style" that defines a
/// text control's key bindings.
///
/// The shared editing keys (printable characters, Backspace, arrows, Home/End,
/// the readline Ctrl-key kills, Tab focus movement) are provided by
/// ``sharedCommand(for:)``. Each concrete keymap only decides the
/// context-specific keys — chiefly what <kbd>Return</kbd> and the up/down arrows
/// mean. ``TextField`` uses ``SingleLineKeymap``; ``TextEditor`` uses
/// ``MultiLineKeymap``.
///
/// This layer is internal; text controls select a keymap for you.
protocol TextInputKeymap: Sendable {
    /// The command a key produces, or ``TextEditCommand/ignore`` to drop it.
    func command(for key: KeyEvent) -> TextEditCommand
}

extension TextInputKeymap {
    /// The mapping common to every text control. Returns `nil` for keys whose
    /// meaning depends on the control (`.enter`, `.up`, `.down`).
    func sharedCommand(for key: KeyEvent) -> TextEditCommand? {
        switch key {
        case .character(let c):     return .insert(c)
        case .backspace:            return .deleteBackward
        case .delete:               return .deleteForward
        case .left:                 return .moveLeft
        case .right:                return .moveRight
        case .home:                 return .moveToLineStart
        case .end:                  return .moveToLineEnd
        case .deleteToStart:        return .deleteToLineStart
        case .deleteToEnd:          return .deleteToLineEnd
        case .deleteWordBackward:   return .deleteWordBackward
        case .tab:                  return .focusNext
        case .backTab:              return .focusPrevious
        case .interrupt:            return .cancel
        case .escape:               return .ignore
        case .enter, .up, .down:    return nil   // control-specific
        }
    }
}

/// The keymap for a single-line ``TextField``: Return submits, and the vertical
/// arrows are left for the surrounding UI.
struct SingleLineKeymap: TextInputKeymap {
    func command(for key: KeyEvent) -> TextEditCommand {
        if let shared = sharedCommand(for: key) { return shared }
        switch key {
        case .enter:      return .submit
        case .up, .down:  return .ignore
        default:          return .ignore
        }
    }
}

/// The keymap for a multi-line ``TextEditor``. Return inserts a newline and the
/// vertical arrows move between lines.
///
/// `Tab`'s meaning follows Textual's `TextArea`: by default **Tab moves focus**
/// (so leaving a control is uniform across every field), matching the plain
/// `TextArea`. Set `indentsWithTab` to `true` for the code-editor behaviour
/// (Textual's `TextArea.code_editor`), where **Tab indents** and Shift-Tab
/// dedents; in that mode you leave the editor with Escape.
struct MultiLineKeymap: TextInputKeymap {
    /// When `true`, Tab/Shift-Tab indent/dedent instead of moving focus.
    var indentsWithTab: Bool = false

    func command(for key: KeyEvent) -> TextEditCommand {
        // Intercept the keys whose meaning differs from a single-line field
        // before consulting the shared mapping.
        switch key {
        case .enter:   return .newline
        case .up:      return .moveUp
        case .down:    return .moveDown
        case .tab:     return indentsWithTab ? .indent : .focusNext
        case .backTab: return indentsWithTab ? .dedent : .focusPrevious
        default:       return sharedCommand(for: key) ?? .ignore
        }
    }
}
