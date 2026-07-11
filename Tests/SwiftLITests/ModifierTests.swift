//
//  ModifierTests.swift
//  SwiftLITests
//
//  Created by Keisuke Chinone on 2026/07/10.
//

#if swift(>=6.0)
import Testing
@_spi(RenderingInternals) @testable import SwiftLI
import Foundation

@Suite("Padding Testing")
struct PaddingTests {
    @Test("EdgeInsets pads each edge by its own amount")
    func edgeInsetsMeasurement() {
        let node = Text("hi")
            .padding(EdgeInsets(top: 1, leading: 2, bottom: 3, trailing: 4))
            .makeNode()
        let size = NodeLayout.measure(node)
        #expect(size.width == 2 + 2 + 4)
        #expect(size.height == 1 + 1 + 3)
    }

    @Test("EdgeInsets offsets the content by its top and leading amounts")
    func edgeInsetsOffset() {
        let node = Text("hi")
            .padding(EdgeInsets(top: 1, leading: 3))
            .makeNode()
        let lines = NodeLayout.frame(of: node).lines.map { TextMetrics.stripANSI($0) }
        #expect(lines.count == 2)
        #expect(lines[0].trimmingCharacters(in: .whitespaces).isEmpty)
        #expect(lines[1] == "   hi")
    }

    @Test("Uniform edge-set padding still works and matches EdgeInsets")
    func edgeSetEquivalence() {
        let viaSet = Text("hi").padding(.horizontal, 2).makeNode()
        let viaInsets = Text("hi").padding(EdgeInsets(leading: 2, trailing: 2)).makeNode()
        #expect(NodeLayout.measure(viaSet) == NodeLayout.measure(viaInsets))
    }

    @Test("Asymmetric horizontal insets narrow maxWidth by their sum")
    func insetsNarrowEnvironment() {
        struct Probe: View {
            @Environment(\.maxWidth) var maxWidth
            var body: some View { Text("W=\(maxWidth)") }
        }
        let view = Probe()
            .padding(EdgeInsets(leading: 3, trailing: 1))
            .frame(width: 30, alignment: .topLeading)
        let out = TextMetrics.stripANSI(view.renderString())
        #expect(out.contains("W=26"))
    }
}

@Suite("Border & Shadow Testing")
struct BorderShadowTests {
    private func plainLines(_ node: RenderNode) -> [String] {
        NodeLayout.frame(of: node).lines.map { TextMetrics.stripANSI($0) }
    }

    @Test("A rounded border wraps content with arc corners and light edges")
    func roundedBorder() {
        let node = Text("Hello").border(.rounded).makeNode()
        let lines = plainLines(node)
        #expect(lines.count == 3)
        #expect(lines[0] == "╭─────╮")
        #expect(lines[1] == "│Hello│")
        #expect(lines[2] == "╰─────╯")
    }

    @Test("Each border style uses its own corner and edge glyphs")
    func borderStyles() {
        #expect(plainLines(Text("X").border(.single).makeNode())[0] == "┌─┐")
        #expect(plainLines(Text("X").border(.double).makeNode())[0] == "╔═╗")
        #expect(plainLines(Text("X").border(.heavy).makeNode())[0] == "┏━┓")
        #expect(plainLines(Text("X").border(.heavy).makeNode())[2] == "┗━┛")
    }

    @Test("A border adds exactly two columns and two rows around its content")
    func borderMeasurement() {
        let inner = NodeLayout.measure(Text("Box").makeNode())
        let outer = NodeLayout.measure(Text("Box").border().makeNode())
        #expect(outer.width == inner.width + 2)
        #expect(outer.height == inner.height + 2)
    }

    @Test("A shadow adds one column and one row to the footprint")
    func shadowMeasurement() {
        let inner = NodeLayout.measure(Text("Card").border().makeNode())
        let outer = NodeLayout.measure(Text("Card").border().shadow().makeNode())
        #expect(outer.width == inner.width + 1)
        #expect(outer.height == inner.height + 1)
    }

    @Test("A shadow leaves the content's own glyphs intact on top")
    func shadowKeepsContent() {
        let lines = plainLines(Text("Card").border(.rounded).shadow().makeNode())
        // The bordered card still reads correctly; the shadow only adds cells
        // to the right and below (which are coloured spaces, blank once ANSI is
        // stripped).
        #expect(lines[0].hasPrefix("╭────╮"))
        #expect(lines[1].hasPrefix("│Card│"))
        #expect(lines[2].hasPrefix("╰────╯"))
        // One extra row for the shadow band below.
        #expect(lines.count == 4)
    }

    @Test("fill paints the whole interior, including padding the content doesn't cover")
    func borderFill() {
        // "Hi" is 2 columns; the frame widens the interior to 6, so 4 interior
        // cells are padding the text never touches.
        let node = Text("Hi").frame(width: 6, alignment: .leading).border(.single, fill: .blue).makeNode()
        let raw = NodeLayout.frame(of: node).lines
        // The blue background (SGR 44) reaches the content row…
        #expect(raw[1].contains("\u{001B}[44m"))
        // …and the visible grid is still a 8-wide box (6 interior + 2 border).
        let grid = raw.map { TextMetrics.stripANSI($0) }
        #expect(grid[0] == "┌──────┐")
        #expect(grid[2] == "└──────┘")
        // Without fill, no background escape is emitted on the content row.
        let noFill = NodeLayout.frame(of: Text("Hi").frame(width: 6, alignment: .leading).border(.single).makeNode()).lines
        #expect(!noFill[1].contains("\u{001B}[44m"))
    }

    @Test("fill also backs the border glyphs so the box is one solid shape")
    func fillBacksBorder() {
        let node = Text("Hi").border(.rounded, fill: .blue).makeNode()
        let raw = NodeLayout.frame(of: node).lines
        // Every row — including the top/bottom border rows and the corners —
        // carries the fill background, leaving no gap at the edge.
        for line in raw {
            #expect(line.contains("\u{001B}[44m"))
        }
    }

    @Test("Border colour changes the escape output but not the glyph grid")
    func borderColour() {
        let plainNode = Text("Hi").border(.rounded).makeNode()
        let colourNode = Text("Hi").border(.rounded, color: .cyan).makeNode()
        // Same visible grid…
        #expect(plainLines(plainNode) == plainLines(colourNode))
        // …different raw ANSI (the colour header is present).
        #expect(NodeLayout.frame(of: plainNode).lines != NodeLayout.frame(of: colourNode).lines)
    }
}

#endif
