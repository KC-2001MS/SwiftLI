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
            (0..<10).map { RenderNode.text(header: "", contents: ["Row \($0)"]) })
        // Offset 3, viewport 4, no scrollbar → rows 3..6.
        let node = RenderNode.scroll(offset: 3, height: 4, thumb: nil, track: nil, child: content)
        let lines = plainLines(node).filter { !$0.isEmpty }
        #expect(lines == ["Row 3", "Row 4", "Row 5", "Row 6"])
        // The viewport height is fixed regardless of content height.
        #expect(NodeLayout.measure(node).height == 4)
    }

    @Test("A scroll offset past the end is clamped to the last window")
    func scrollClampsAtEnd() {
        let content = RenderNode.vstack(alignment: .leading, spacing: 0, children:
            (0..<5).map { RenderNode.text(header: "", contents: ["L\($0)"]) })
        let node = RenderNode.scroll(offset: 99, height: 3, thumb: nil, track: nil, child: content)
        let lines = plainLines(node).filter { !$0.isEmpty }
        #expect(lines == ["L2", "L3", "L4"])
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
        let node = RenderNode.hscroll(offset: 2, extent: 4, thumb: nil, track: nil,
                                      child: Text(verbatim: "abcdefghij").makeNode())
        let lines = NodeLayout.frame(of: node).lines.map { TextMetrics.stripANSI($0) }
        #expect(lines.first == "cdef")
    }

    @Test("An hscroll offset past the end is clamped to the last window")
    func hscrollClampsAtEnd() {
        let node = RenderNode.hscroll(offset: 999, extent: 4, thumb: nil, track: nil,
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

#endif
