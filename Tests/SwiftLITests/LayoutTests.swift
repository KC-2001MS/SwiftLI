//
//  LayoutTests.swift
//  SwiftLITests
//
//  Created by Keisuke Chinone on 2026/07/10.
//

#if swift(>=6.0)
import Testing
@_spi(RenderingInternals) @testable import SwiftLI
import Foundation

@Suite("HStack / VStack Layout Testing")
struct StackLayoutTests {
    @Test("HStack of Texts produces correct size")
    func hstackMeasure() {
        let stack = HStack(spacing: 1) {
            Text("AB")
            Text("CD")
        }
        let size = stack.measure()
        // "AB" = 2 cols, spacing = 1, "CD" = 2 cols → width 5, height 1
        #expect(size.width == 5)
        #expect(size.height == 1)
    }

    @Test("VStack of Texts produces correct size")
    func vstackMeasure() {
        let stack = VStack {
            Text("Hello")
            Text("Hi")
        }
        let size = stack.measure()
        // width = max(5, 2) = 5, height = 1 + 1 = 2
        #expect(size.width == 5)
        #expect(size.height == 2)
    }

    @Test("VStack { HStack { VStack { HStack } } } — deep nesting does not crash")
    func deepNestedStack() {
        let nested = VStack {
            HStack(spacing: 1) {
                VStack {
                    Text("A")
                    Text("B")
                }
                Text("|")
                VStack {
                    HStack(spacing: 1) {
                        Text("C")
                        Text("D")
                    }
                    HStack(spacing: 1) {
                        Text("E")
                        Text("F")
                    }
                }
            }
            Text("---bottom---")
        }
        let size = nested.measure()
        // Should produce a valid non-zero size without crashing
        #expect(size.width > 0)
        #expect(size.height > 0)
    }

    @Test("HStack renderString contains child text in order")
    func hstackRenderString() {
        let stack = HStack {
            Text("Left")
            Text("Right")
        }
        let s = stack.renderString()
        let plain = s.replacingOccurrences(of: "\u{001B}[0m", with: "")
        #expect(plain.contains("Left"))
        #expect(plain.contains("Right"))
        // Left must appear before Right
        let leftIdx = plain.range(of: "Left")!.lowerBound
        let rightIdx = plain.range(of: "Right")!.lowerBound
        #expect(leftIdx < rightIdx)
    }

    @Test("HStack with Divider renders vertical bar between children")
    func hstackDividerRendersVerticalBar() {
        let stack = HStack(spacing: 1) {
            Text("Left")
            Divider()
            Text("Right")
        }
        let s = stack.renderString()
        // Strip ANSI escape sequences to get plain text
        var plain = ""
        var i = s.startIndex
        while i < s.endIndex {
            if s[i] == "\u{001B}" {
                i = s.index(after: i)
                while i < s.endIndex {
                    let c = s[i]; i = s.index(after: i)
                    if c == "m" { break }
                }
            } else {
                plain.append(s[i]); i = s.index(after: i)
            }
        }
        #expect(plain.contains("|"))
        #expect(plain.contains("Left"))
        #expect(plain.contains("Right"))
    }

    @Test("VStack with Divider renders horizontal line between children")
    func vstackDividerRendersHorizontalLine() {
        let stack = VStack {
            Text("Above")
            Divider(5)
            Text("Below")
        }
        // Strip all ANSI escape sequences before checking plain text content.
        let raw = stack.renderString()
        let plain = raw.replacingOccurrences(of: "\u{001B}\\[[^m]*m", with: "", options: .regularExpression)
        #expect(plain.contains("-----"))
        #expect(plain.contains("Above"))
        #expect(plain.contains("Below"))
    }

    @Test("VStack trailing alignment offsets shorter row")
    func vstackTrailingAlignment() {
        let canvas = TerminalCanvas(width: 0, height: 0)
        let stack = VStack(alignment: .trailing) {
            Text("Hi")        // 2 chars
            Text("Hello")     // 5 chars — widest
        }
        stack.draw(into: canvas, at: .zero)
        let lines = canvas.toString().components(separatedBy: "\n")
        // First row ("Hi") must start at column 3 (5-2=3), so the first 3 cells
        // of the first line contain only spaces.
        let first = lines[0]
        let plain = first.replacingOccurrences(of: "\u{001B}[0m", with: "")
        #expect(plain.hasPrefix("   "))  // 3 leading spaces
    }
}

@Suite("Frame & Wrapping Testing")
struct FrameWrappingTests {
    private func plainLines(_ node: RenderNode) -> [String] {
        NodeLayout.frame(of: node).lines.map { TextMetrics.stripANSI($0) }
    }

    @Test("Word wrap breaks at spaces and never exceeds the column budget")
    func wordWrap() {
        let lines = NodeLayout.wrap("The quick brown fox jumps", toColumns: 10)
        for line in lines { #expect(TextMetrics.visibleWidth(line) <= 10) }
        #expect(lines.count >= 3)
        // Words are kept intact (no mid-word split at a boundary here).
        #expect(lines.allSatisfy { !$0.hasPrefix(" ") })
    }

    @Test("A long word with no spaces is hard-broken to the width")
    func hardBreak() {
        let lines = NodeLayout.wrap("abcdefghijklmnop", toColumns: 5)
        #expect(lines.count == 4)
        for line in lines { #expect(TextMetrics.visibleWidth(line) <= 5) }
    }

    @Test("Wide (CJK) glyphs wrap without splitting a two-column cell")
    func wideWrap() {
        let lines = NodeLayout.wrap("あいうえおかきくけこ", toColumns: 7)
        for line in lines { #expect(TextMetrics.visibleWidth(line) <= 7) }
    }

    @Test("A width-constrained frame wraps its text onto multiple rows")
    func frameWraps() {
        let node = Text("The quick brown fox jumps over the lazy dog")
            .frame(width: 20, alignment: .topLeading)
            .makeNode()
        let lines = plainLines(node)
        #expect(lines.count > 1)
        for line in lines { #expect(TextMetrics.visibleWidth(line) <= 20) }
    }

    @Test("lineLimit caps the visual line count and ends with an ellipsis")
    func lineLimitEllipsis() {
        let node = Text("The quick brown fox jumps over the lazy dog")
            .frame(width: 20, alignment: .topLeading)
            .lineLimit(2)
            .makeNode()
        let lines = plainLines(node)
        #expect(lines.count == 2)
        #expect(lines.last?.contains("…") == true)
    }

    @Test("A fixed frame pads a smaller child to its width and height")
    func fixedFramePads() {
        let node = Text("hi").frame(width: 10, height: 3, alignment: .center).makeNode()
        let size = NodeLayout.measure(node)
        #expect(size.width == 10)
        #expect(size.height == 3)
    }

    @Test("A fixed-height frame ends overflowing text with an ellipsis")
    func frameHeightEllipsis() {
        let node = Text("The quick brown fox jumps over the lazy dog")
            .frame(width: 20, height: 2, alignment: .topLeading)
            .makeNode()
        let lines = plainLines(node)
        #expect(lines.count == 2)
        #expect(lines.last?.contains("…") == true)
    }

    @Test("A frame clips content taller than its fixed height")
    func fixedFrameClips() {
        let tall = VStack(alignment: .leading) {
            Text("one"); Text("two"); Text("three"); Text("four")
        }
        let node = tall.frame(height: 2, alignment: .topLeading).makeNode()
        let lines = plainLines(node).filter { !$0.isEmpty }
        #expect(lines.count <= 2)
        #expect(lines.first == "one")
    }

    @Test("A scroll node shows a height-row window offset from the top")
    func scrollWindow() {
        let content = RenderNode.vstack(alignment: .leading, spacing: 0, children:
            (0..<10).map { RenderNode.text(style: .plain, contents: ["Row \($0)"]) })
        // Offset 3, viewport 4, no scrollbar → rows 3..6.
        let node = RenderNode.scroll(offset: 3, height: 4, bar: nil, width: nil, child: content)
        let lines = plainLines(node).filter { !$0.isEmpty }
        #expect(lines == ["Row 3", "Row 4", "Row 5", "Row 6"])
        // The viewport height is fixed regardless of content height.
        #expect(NodeLayout.measure(node).height == 4)
    }

    @Test("A scroll offset past the end is clamped to the last window")
    func scrollClampsAtEnd() {
        let content = RenderNode.vstack(alignment: .leading, spacing: 0, children:
            (0..<5).map { RenderNode.text(style: .plain, contents: ["L\($0)"]) })
        let node = RenderNode.scroll(offset: 99, height: 3, bar: nil, width: nil, child: content)
        let lines = plainLines(node).filter { !$0.isEmpty }
        #expect(lines == ["L2", "L3", "L4"])
    }

    private var plainBar: ScrollBar {
        ScrollBar(thumb: .cyan, track: .eight_bit(238))
    }

    @Test("The scrollbar is pinned to the far edge of the viewport's width")
    func scrollBarAtFarEdge() {
        let content = RenderNode.vstack(alignment: .leading, spacing: 0, children:
            (0..<6).map { RenderNode.text(style: .plain, contents: ["ab\($0)"]) })
        let node = RenderNode.scroll(offset: 0, height: 3, bar: plainBar, width: 12, child: content)
        let lines = plainLines(node)
        #expect(lines.count == 3)
        for line in lines {
            // Content on the left, then a gap, then the bar in the last column.
            #expect(TextMetrics.visibleWidth(line) == 12)
            #expect(["█", "▀", "▄"].contains(String(line.suffix(1))))
        }
        #expect(NodeLayout.measure(node).width == 12)
    }

    @Test("The scrollbar is a continuous solid strip with half-block end caps")
    func scrollBarHalfBlockPrecision() {
        // 8 content rows through a 4-row viewport → the thumb is exactly two
        // rows (four half rows). Offset 1 shifts it by one half row, so its
        // ends land mid-cell: ▄ on the entering cell, ▀ on the leaving one,
        // and the remaining track cells stay solid — no gaps anywhere.
        let content = RenderNode.vstack(alignment: .leading, spacing: 0, children:
            (0..<8).map { RenderNode.text(style: .plain, contents: ["r\($0)"]) })
        let node = RenderNode.scroll(offset: 1, height: 4, bar: plainBar, width: nil, child: content)
        let caps = plainLines(node).map { String($0.suffix(1)) }
        #expect(caps == ["▄", "█", "▀", "█"])
    }
}

@Suite("Horizontal Scroll Testing")
struct HScrollTests {
    @Test("sliceColumns keeps only the requested visible-column window")
    func sliceWindow() {
        #expect(TextMetrics.stripANSI(TextMetrics.sliceColumns("abcdefgh", from: 2, width: 3)) == "cde")
        #expect(TextMetrics.stripANSI(TextMetrics.sliceColumns("abcdefgh", from: 0, width: 4)) == "abcd")
        // A window past the end simply yields what remains.
        #expect(TextMetrics.stripANSI(TextMetrics.sliceColumns("abc", from: 1, width: 10)) == "bc")
    }

    @Test("An hscroll node shows an extent-wide column window offset from the left")
    func hscrollWindow() {
        let node = RenderNode.hscroll(offset: 2, extent: 4, bar: nil,
                                      child: Text(verbatim: "abcdefghij").makeNode())
        let lines = NodeLayout.frame(of: node).lines.map { TextMetrics.stripANSI($0) }
        #expect(lines.first == "cdef")
    }

    @Test("An hscroll offset past the end is clamped to the last window")
    func hscrollClampsAtEnd() {
        let node = RenderNode.hscroll(offset: 999, extent: 4, bar: nil,
                                      child: Text(verbatim: "abcdefghij").makeNode())
        let lines = NodeLayout.frame(of: node).lines.map { TextMetrics.stripANSI($0) }
        // 10 columns, window 4 → max offset 6 → last window is "ghij".
        #expect(lines.first == "ghij")
    }
}

@Suite("ViewThatFits Testing")
struct ViewThatFitsTests {
    private func plain(_ node: RenderNode, width: Int?) -> String {
        NodeLayout.frame(of: node).lines.map { TextMetrics.stripANSI($0) }.joined(separator: "\n")
    }

    @ViewBuilder
    private var candidates: some View {
        ViewThatFits {
            Text("Full download progress: 42% complete")
            Text("42% complete")
            Text("42%")
        }
    }

    @Test("Picks the widest candidate that fits the proposed width")
    func picksWidestFitting() {
        let node = candidates.makeNode()
        // Width 20 → the 36-col line and the 12-col line: "42% complete" (12) fits, full (36) doesn't.
        let chosen = NodeLayout.fittingCandidate(
            [Text("Full download progress: 42% complete").makeNode(),
             Text("42% complete").makeNode(),
             Text("42%").makeNode()],
            checkWidth: true, checkHeight: false, proposedWidth: 20, lineLimit: nil
        )
        #expect(TextMetrics.stripANSI(NodeLayout.frame(of: chosen).lines.joined()) == "42% complete")
        _ = node
    }

    @Test("Falls back to the last candidate when none fit")
    func fallsBackToLast() {
        let chosen = NodeLayout.fittingCandidate(
            [Text("aaaaaaaa").makeNode(), Text("bbbbb").makeNode(), Text("ccc").makeNode()],
            checkWidth: true, checkHeight: false, proposedWidth: 2, lineLimit: nil
        )
        #expect(TextMetrics.stripANSI(NodeLayout.frame(of: chosen).lines.joined()) == "ccc")
    }

    @Test("Uses the first candidate when it already fits")
    func usesFirstWhenItFits() {
        let chosen = NodeLayout.fittingCandidate(
            [Text("hi").makeNode(), Text("h").makeNode()],
            checkWidth: true, checkHeight: false, proposedWidth: 40, lineLimit: nil
        )
        #expect(TextMetrics.stripANSI(NodeLayout.frame(of: chosen).lines.joined()) == "hi")
    }
}

// MARK: - Form / Section testing

@Suite("Form / Section Testing")
struct FormSectionTests {
    @Test("Section renders its header above indented content and a footer below")
    func sectionLayout() {
        let section = Section {
            Text("Row1")
            Text("Row2")
        } header: {
            Text("HEAD")
        } footer: {
            Text("note")
        }
        let lines = TextMetrics.stripANSI(section.renderString())
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        #expect(lines == ["HEAD", "Row1", "Row2", "note"])

        // The content is indented two columns under the header.
        let raw = TextMetrics.stripANSI(section.renderString())
        #expect(raw.contains("  Row1"))
        #expect(raw.contains("  note"))
    }

    @Test("A title-only Section has no footer; an untitled one has no header")
    func sectionVariants() {
        let titled = TextMetrics.stripANSI(Section("Account") { Text("row") }.renderString())
        #expect(titled.contains("Account"))
        #expect(titled.contains("  row"))

        let untitled = TextMetrics.stripANSI(Section { Text("row") }.renderString())
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        #expect(untitled == ["row"])
    }

    @Test("Form stacks sections with a blank line between them")
    func formSpacing() {
        let form = Form {
            Section("A") { Text("r1") }
            Section("B") { Text("r2") }
        }
        let out = TextMetrics.stripANSI(form.renderString())
        // Sections appear in order…
        let a = out.range(of: "A")!.lowerBound
        let r1 = out.range(of: "r1")!.lowerBound
        let b = out.range(of: "B")!.lowerBound
        let r2 = out.range(of: "r2")!.lowerBound
        #expect(a < r1 && r1 < b && b < r2)
        // …separated by one blank line (VStack spacing 1).
        let lines = out.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        #expect(lines.contains(""))
    }
}

#endif
