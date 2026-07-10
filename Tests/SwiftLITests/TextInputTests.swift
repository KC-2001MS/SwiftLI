//
//  TextInputTests.swift
//  SwiftLITests
//
//  Created by Keisuke Chinone on 2026/07/10.
//

#if swift(>=6.0)
import Testing
@_spi(RenderingInternals) @testable import SwiftLI
import Foundation

@Suite("TextField Input Testing")
struct TextFieldInputTests {

    // MARK: TextFieldEditor (pure editing model, driven by commands)

    @Test("Insert commands add characters at the cursor and advance it")
    func typingInserts() {
        var result = TextFieldEditor.Result(text: "", cursor: 0)
        for ch in "Hi" {
            result = TextFieldEditor.apply(.insert(ch), to: result.text, cursor: result.cursor)
        }
        #expect(result.text == "Hi")
        #expect(result.cursor == 2)
    }

    @Test("A character is inserted at the cursor, not appended")
    func insertsAtCursor() {
        let result = TextFieldEditor.apply(.insert("X"), to: "ac", cursor: 1)
        #expect(result.text == "aXc")
        #expect(result.cursor == 2)
    }

    @Test("deleteBackward removes the character before the cursor")
    func backspaceDeletes() {
        let result = TextFieldEditor.apply(.deleteBackward, to: "Hi", cursor: 2)
        #expect(result.text == "H")
        #expect(result.cursor == 1)
    }

    @Test("Line-start/end and left/right move the cursor without editing")
    func cursorMovesOnly() {
        #expect(TextFieldEditor.apply(.moveToLineStart, to: "abc", cursor: 3).cursor == 0)
        #expect(TextFieldEditor.apply(.moveToLineEnd, to: "abc", cursor: 0).cursor == 3)
        #expect(TextFieldEditor.apply(.moveLeft, to: "abc", cursor: 2).cursor == 1)
        #expect(TextFieldEditor.apply(.moveRight, to: "abc", cursor: 1).cursor == 2)
        #expect(TextFieldEditor.apply(.moveToLineStart, to: "abc", cursor: 3).text == "abc")
    }

    @Test("deleteToLineStart / deleteToLineEnd / deleteWordBackward kill text")
    func killEdits() {
        #expect(TextFieldEditor.apply(.deleteToLineStart, to: "hello world", cursor: 6).text == "world")
        #expect(TextFieldEditor.apply(.deleteToLineStart, to: "hello world", cursor: 6).cursor == 0)
        #expect(TextFieldEditor.apply(.deleteToLineEnd, to: "hello world", cursor: 5).text == "hello")
        #expect(TextFieldEditor.apply(.deleteWordBackward, to: "foo bar", cursor: 7).text == "foo ")
        #expect(TextFieldEditor.apply(.deleteWordBackward, to: "foo bar ", cursor: 8).text == "foo ")
    }

    // MARK: KeyDecoder (control-key line editing matches the terminal norm)

    @Test("Emacs/readline control keys decode to the matching editing events")
    func decodesControlKeys() {
        var decoder = KeyDecoder()
        #expect(decoder.feed([0x01]) == [.home])              // Ctrl-A
        #expect(decoder.feed([0x05]) == [.end])               // Ctrl-E
        #expect(decoder.feed([0x02]) == [.left])              // Ctrl-B
        #expect(decoder.feed([0x06]) == [.right])             // Ctrl-F
        #expect(decoder.feed([0x04]) == [.delete])            // Ctrl-D
        #expect(decoder.feed([0x0B]) == [.deleteToEnd])       // Ctrl-K
        #expect(decoder.feed([0x15]) == [.deleteToStart])     // Ctrl-U
        #expect(decoder.feed([0x17]) == [.deleteWordBackward]) // Ctrl-W
    }

    // MARK: TextInputKeymap (the style that maps keys → commands)

    @Test("Shared keys map to the same command regardless of keymap")
    func sharedKeymap() {
        #expect(SingleLineKeymap().command(for: .character("a")) == .insert("a"))
        #expect(SingleLineKeymap().command(for: .backspace) == .deleteBackward)
        #expect(MultiLineKeymap().command(for: .character("a")) == .insert("a"))
        #expect(SingleLineKeymap().command(for: .tab) == .focusNext)
    }

    @Test("Return and up/down differ between the single-line and multi-line keymaps")
    func contextualKeymap() {
        #expect(SingleLineKeymap().command(for: .enter) == .submit)
        #expect(SingleLineKeymap().command(for: .up) == .ignore)
        #expect(MultiLineKeymap().command(for: .enter) == .newline)
        #expect(MultiLineKeymap().command(for: .up) == .moveUp)
        #expect(MultiLineKeymap().command(for: .down) == .moveDown)
    }
}

// MARK: - TextEditor (multi-line) input testing

@Suite("TextEditor Input Testing")
struct TextEditorInputTests {
    @Test("The newline command splits the line")
    func insertNewline() {
        let r = TextFieldEditor.apply(.newline, to: "ab", cursor: 2)
        #expect(r.text == "ab\n")
        #expect(r.cursor == 3)
    }

    @Test("Line-start/end are line-local across multiple lines")
    func lineLocalHomeEnd() {
        // "abc\ndef": cursor 5 sits on the 2nd line (between d and e).
        #expect(TextFieldEditor.apply(.moveToLineStart, to: "abc\ndef", cursor: 5).cursor == 4)
        #expect(TextFieldEditor.apply(.moveToLineEnd, to: "abc\ndef", cursor: 5).cursor == 7)
    }

    @Test("moveUp / moveDown go to the same column on the adjacent line")
    func verticalMovement() {
        // "abc\nde": cursor 6 (end of 2nd line, column 2) → up to column 2 of line 1.
        #expect(TextFieldEditor.apply(.moveUp, to: "abc\nde", cursor: 6).cursor == 2)
        // "abc\ndef": cursor 1 (line 1, column 1) → down to column 1 of line 2.
        #expect(TextFieldEditor.apply(.moveDown, to: "abc\ndef", cursor: 1).cursor == 5)
    }

    @Test("moveUp on the first line and moveDown on the last line are no-ops")
    func verticalEdges() {
        #expect(TextFieldEditor.apply(.moveUp, to: "abc\ndef", cursor: 1).cursor == 1)
        #expect(TextFieldEditor.apply(.moveDown, to: "abc\ndef", cursor: 5).cursor == 5)
    }

    @Test("Indent inserts spaces at the cursor; dedent removes leading spaces")
    func indentDedent() {
        let indented = TextFieldEditor.apply(.indent, to: "ab", cursor: 2)
        #expect(indented.text == "ab    ")       // 4 spaces
        #expect(indented.cursor == 6)

        let dedented = TextFieldEditor.apply(.dedent, to: "    x", cursor: 5)
        #expect(dedented.text == "x")            // 4 leading spaces removed
        #expect(dedented.cursor == 1)
    }

    @Test("By default the multi-line keymap maps Tab to focus movement (Textual TextArea)")
    func multiLineTabMovesFocus() {
        #expect(MultiLineKeymap().command(for: .tab) == .focusNext)
        #expect(MultiLineKeymap().command(for: .backTab) == .focusPrevious)
        // A single-line field also uses Tab for focus movement.
        #expect(SingleLineKeymap().command(for: .tab) == .focusNext)
    }

    @Test("The code-editor keymap maps Tab to indent (Textual TextArea.code_editor)")
    func multiLineTabIndentsWhenOptedIn() {
        let code = MultiLineKeymap(indentsWithTab: true)
        #expect(code.command(for: .tab) == .indent)
        #expect(code.command(for: .backTab) == .dedent)
        // Everything else matches the default multi-line keymap.
        #expect(code.command(for: .enter) == .newline)
    }
}

#endif
