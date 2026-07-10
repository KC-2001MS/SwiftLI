//
//  RenderingTests.swift
//  SwiftLITests
//
//  Created by Keisuke Chinone on 2026/07/10.
//

#if swift(>=6.0)
import Testing
@_spi(RenderingInternals) @testable import SwiftLI
import Foundation

@Suite("IR Conditional & Diff Testing")
struct ConditionalDiffTests {

    /// A VStack whose middle row is chosen by an `if`/`else`; the surrounding
    /// rows and the overall width stay constant.
    private func sameWidthBranch(_ on: Bool) -> VStack {
        VStack {
            Text("top")
            if on { Text("AAAAA") } else { Text("BBBBB") }
            Text("bot")
        }
    }

    @Test("if/else selects the active branch in the lowered frame")
    func ifElseSelectsBranch() {
        let onFrame  = NodeLayout.frame(of: sameWidthBranch(true).makeNode())
        let offFrame = NodeLayout.frame(of: sameWidthBranch(false).makeNode())
        #expect(onFrame.lines.contains { sgrStripped($0) == "AAAAA" })
        #expect(!onFrame.lines.contains { sgrStripped($0) == "BBBBB" })
        #expect(offFrame.lines.contains { sgrStripped($0) == "BBBBB" })
        #expect(!offFrame.lines.contains { sgrStripped($0) == "AAAAA" })
    }

    @Test("Same-width if/else swap rewrites only the changed line")
    func sameWidthSwapRewritesOnlyChangedLine() {
        let a = NodeLayout.frame(of: sameWidthBranch(true).makeNode())
        let b = NodeLayout.frame(of: sameWidthBranch(false).makeNode())
        let diff = FrameDiff.inlineUpdate(from: a, to: b)

        // Exactly one line changed, so exactly one erase-line sequence.
        #expect(occurrences(of: eraseLineCode, in: diff) == 1)
        // The new content is emitted…
        #expect(sgrStripped(diff).contains("BBBBB"))
        // …and the unchanged surrounding rows are NOT rewritten (skipped).
        #expect(!sgrStripped(diff).contains("top"))
        #expect(!sgrStripped(diff).contains("bot"))
    }

    /// An HStack where the left VStack's width is driven by an `if`/`else`.
    /// Widening the left column must shift the divider and right column.
    private func widthPropagating(_ wide: Bool) -> HStack {
        HStack(spacing: 1) {
            VStack {
                Text("T")
                if wide { Text("wwwwwwww") } else { Text("s") }
            }
            Text("|")
            VStack {
                Text("R1")
                Text("R2")
            }
        }
    }

    @Test("Widening one column shifts siblings, and the diff redraws them")
    func widthChangePropagatesToSiblings() {
        let narrow = NodeLayout.frame(of: widthPropagating(false).makeNode())
        let wide   = NodeLayout.frame(of: widthPropagating(true).makeNode())

        // Row 0's left cell ("T") is textually unchanged, yet the whole row
        // differs because the right column shifted — exactly the propagation
        // the diff must catch.
        #expect(sgrStripped(narrow.lines[0]) != sgrStripped(wide.lines[0]))
        #expect(sgrStripped(narrow.lines[0]).contains("R1"))
        #expect(sgrStripped(wide.lines[0]).contains("R1"))

        let diff = FrameDiff.inlineUpdate(from: narrow, to: wide)
        // Both rows changed (row 0 shifted, row 1 shifted + text swapped).
        #expect(occurrences(of: eraseLineCode, in: diff) == 2)
        // The shifted right column is part of the rewritten output.
        #expect(sgrStripped(diff).contains("R1"))
    }

    /// A VStack whose row count is driven by an `if` (no `else`).
    private func rowCount(_ many: Bool) -> VStack {
        VStack {
            Text("a")
            Text("b")
            if many {
                Text("c")
                Text("d")
            }
        }
    }

    @Test("Shrinking the frame erases the rows that disappeared")
    func shrinkingFrameErasesExtraRows() {
        let tall  = NodeLayout.frame(of: rowCount(true).makeNode())   // 4 rows
        let short = NodeLayout.frame(of: rowCount(false).makeNode())  // 2 rows
        #expect(tall.lines.count == 4)
        #expect(short.lines.count == 2)

        let diff = FrameDiff.inlineUpdate(from: tall, to: short)
        // Rows "a"/"b" are unchanged (skipped); the two vanished rows are erased.
        #expect(occurrences(of: eraseLineCode, in: diff) == 2)
        #expect(!sgrStripped(diff).contains("a"))
    }

    @Test("Growing the frame appends the new rows")
    func growingFrameAppendsRows() {
        let short = NodeLayout.frame(of: rowCount(false).makeNode())  // 2 rows
        let tall  = NodeLayout.frame(of: rowCount(true).makeNode())   // 4 rows

        let diff = FrameDiff.inlineUpdate(from: short, to: tall)
        // Existing rows unchanged; the two appended rows are written (erased+drawn).
        #expect(occurrences(of: eraseLineCode, in: diff) == 2)
        #expect(sgrStripped(diff).contains("c"))
        #expect(sgrStripped(diff).contains("d"))
    }

    @Test("Full-screen diff also redraws only changed lines")
    func fullScreenDiffRedrawsChangedLines() {
        let a = NodeLayout.frame(of: sameWidthBranch(true).makeNode())
        let b = NodeLayout.frame(of: sameWidthBranch(false).makeNode())
        let diff = FrameDiff.fullScreenUpdate(from: a, to: b)
        // Only the middle line is repositioned & rewritten.
        #expect(occurrences(of: eraseLineCode, in: diff) == 1)
        #expect(sgrStripped(diff).contains("BBBBB"))
        #expect(!sgrStripped(diff).contains("top"))
    }
}

@Suite("Hidden Blanking Testing")
struct HiddenBlankingTests {

    @Test("hidden() blanks the glyphs but keeps the same width")
    func hiddenBlanksGlyphsPreservingWidth() {
        let shown  = NodeLayout.frame(of: Text("Hello").makeNode())
        let hidden = NodeLayout.frame(of: Text("Hello").hidden().makeNode())
        // Same measured size — the layout is untouched.
        #expect(NodeLayout.measure(Text("Hello").makeNode())
                == NodeLayout.measure(Text("Hello").hidden().makeNode()))
        // Original text is visible; hidden text is the same width, all spaces.
        #expect(sgrStripped(shown.lines[0]) == "Hello")
        #expect(sgrStripped(hidden.lines[0]) == "     ")   // 5 spaces, no glyphs
    }

    @Test("A hidden field inside an HStack does not shift its neighbours")
    func hiddenKeepsNeighboursInPlace() {
        func row(_ hide: Bool) -> HStack {
            HStack(spacing: 1) {
                Text("name:")
                Text("secret").hidden(hide)
                Text("<")
            }
        }
        let shown  = NodeLayout.frame(of: row(false).makeNode())
        let hidden = NodeLayout.frame(of: row(true).makeNode())

        // The trailing "<" sits at the exact same column in both states,
        // because the hidden field still occupies "secret".count columns.
        let shownPlain  = sgrStripped(shown.lines[0])
        let hiddenPlain = sgrStripped(hidden.lines[0])
        #expect(shownPlain  == "name: secret <")
        #expect(hiddenPlain == "name:        <")   // "secret" → 6 spaces, "<" unmoved
        #expect(shownPlain.count == hiddenPlain.count)
    }

    @Test("hidden() blanks a wide (2-column) character to two spaces")
    func hiddenBlanksWideCharacter() {
        // A full-width character ("あ") occupies two columns, so hiding it must
        // emit two spaces to preserve the width.
        #expect(NodeLayout.blankedGlyphs(of: "あ") == "  ")
        #expect(NodeLayout.blankedGlyphs(of: "ab") == "  ")
        // End to end: the hidden wide glyph leaves the trailing bar two columns in.
        let hidden = NodeLayout.frame(of: HStack { Text("あ").hidden(); Text("|") }.makeNode())
        #expect(sgrStripped(hidden.lines[0]) == "  |")
    }
}

// MARK: - Line clipping (wrap-safety) testing

@Suite("Line Clipping Testing")
struct LineClippingTests {
    private func visibleWidth(_ s: String) -> Int {
        TextMetrics.visibleWidth(TextMetrics.stripANSI(s))
    }

    @Test("Clips a plain line to the column limit")
    func clipsPlain() {
        let clipped = TextMetrics.truncate(String(repeating: "X", count: 40), toColumns: 20)
        #expect(visibleWidth(clipped) == 20)
    }

    @Test("A line at or below the limit is left unchanged")
    func keepsShort() {
        let s = "\u{001B}[32mHello\u{001B}[0m"
        #expect(TextMetrics.truncate(s, toColumns: 20) == s)
    }

    @Test("Escape sequences don't count toward the width and a reset is appended when cut")
    func preservesANSIAndResets() {
        let styled = "\u{001B}[32m" + String(repeating: "X", count: 40) + "\u{001B}[0m"
        let clipped = TextMetrics.truncate(styled, toColumns: 20)
        #expect(visibleWidth(clipped) == 20)
        #expect(clipped.hasPrefix("\u{001B}[32m"))
        #expect(clipped.hasSuffix("\u{001B}[0m"))
    }

    @Test("A wide (2-column) glyph is dropped rather than split at the boundary")
    func doesNotSplitWideGlyph() {
        // 15 full-width characters = 30 columns; clipping to 21 keeps 10 (= 20
        // columns) and drops the 11th rather than emitting a half-width cell.
        let clipped = TextMetrics.truncate(String(repeating: "あ", count: 15), toColumns: 21)
        #expect(visibleWidth(clipped) == 20)
    }
}

@Suite("Grapheme Width Testing")
struct GraphemeWidthTests {
    @Test("ASCII is one column per character")
    func ascii() {
        #expect(TextMetrics.visibleWidth("Hello") == 5)
    }

    @Test("CJK and full-width glyphs are two columns each")
    func wideCJK() {
        #expect(TextMetrics.visibleWidth("あ") == 2)
        #expect(TextMetrics.visibleWidth("日本語") == 6)
        #expect(TextMetrics.visibleWidth("Ａ") == 2)   // full-width A
        #expect(TextMetrics.visibleWidth("　") == 2)   // ideographic space
    }

    @Test("Emoji count as two columns, including presentation and VS16 forms")
    func emoji() {
        #expect(TextMetrics.width(of: "😀") == 2)
        #expect(TextMetrics.width(of: "❤️") == 2)   // U+2764 + VS16
        #expect(TextMetrics.visibleWidth("a😀b") == 4)
    }

    @Test("A ZWJ family and a flag are single double-width clusters")
    func compoundEmoji() {
        #expect(TextMetrics.width(of: "👨‍👩‍👧‍👦") == 2)   // ZWJ family
        #expect(TextMetrics.width(of: "🇯🇵") == 2)          // regional-indicator flag
    }

    @Test("Combining marks compose onto their base and add no width")
    func combiningMarks() {
        // "e" + combining acute accent is one grapheme cluster, one column.
        #expect(TextMetrics.visibleWidth("e\u{0301}") == 1)
        #expect(TextMetrics.visibleWidth("café") == 4)
    }
}

#endif
