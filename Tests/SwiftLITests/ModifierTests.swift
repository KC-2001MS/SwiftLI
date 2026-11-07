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
        let node = Text("Hello").border(.primary).makeNode()
        let lines = plainLines(node)
        #expect(lines.count == 3)
        #expect(lines[0] == "╭─────╮")
        #expect(lines[1] == "│Hello│")
        #expect(lines[2] == "╰─────╯")
    }

    @Test("Each border style uses its own corner and edge glyphs")
    func borderStyles() {
        #expect(plainLines(Text("X").border(.primary, style: .single).makeNode())[0] == "┌─┐")
        #expect(plainLines(Text("X").border(.primary, style: .double).makeNode())[0] == "╔═╗")
        #expect(plainLines(Text("X").border(.primary, style: .heavy).makeNode())[0] == "┏━┓")
        #expect(plainLines(Text("X").border(.primary, style: .heavy).makeNode())[2] == "┗━┛")
    }

    @Test("A border adds exactly two columns and two rows around its content")
    func borderMeasurement() {
        let inner = NodeLayout.measure(Text("Box").makeNode())
        let outer = NodeLayout.measure(Text("Box").border(.primary).makeNode())
        #expect(outer.width == inner.width + 2)
        #expect(outer.height == inner.height + 2)
    }

    @Test("A shadow adds one column and one row to the footprint")
    func shadowMeasurement() {
        let inner = NodeLayout.measure(Text("Card").border(.primary).makeNode())
        let outer = NodeLayout.measure(Text("Card").border(.primary).shadow(x: 1, y: 1).makeNode())
        #expect(outer.width == inner.width + 1)
        #expect(outer.height == inner.height + 1)
    }

    @Test("A shadow leaves the content's own glyphs intact on top")
    func shadowKeepsContent() {
        let lines = plainLines(Text("Card").border(.primary).shadow(x: 1, y: 1).makeNode())
        // The bordered card still reads correctly; the shadow only adds cells
        // to the right and below (which are coloured spaces, blank once ANSI is
        // stripped).
        #expect(lines[0].hasPrefix("╭────╮"))
        #expect(lines[1].hasPrefix("│Card│"))
        #expect(lines[2].hasPrefix("╰────╯"))
        // One extra row for the shadow band below.
        #expect(lines.count == 4)
    }

    @Test("A background over a border paints the whole interior, including padding the content doesn't cover")
    func borderFill() {
        // "Hi" is 2 columns; the frame widens the interior to 6, so 4 interior
        // cells are padding the text never touches.
        let node = Text("Hi").frame(width: 6, alignment: .leading).border(.primary, style: .single).background(.blue).makeNode()
        let raw = NodeLayout.frame(of: node).lines
        // The blue background (SGR 44) reaches the content row…
        #expect(raw[1].contains("\u{001B}[44m"))
        // …and the visible grid is still a 8-wide box (6 interior + 2 border).
        let grid = raw.map { TextMetrics.stripANSI($0) }
        #expect(grid[0] == "┌──────┐")
        #expect(grid[2] == "└──────┘")
        // Without a background, no background escape is emitted on the content row.
        let noFill = NodeLayout.frame(of: Text("Hi").frame(width: 6, alignment: .leading).border(.primary, style: .single).makeNode()).lines
        #expect(!noFill[1].contains("\u{001B}[44m"))
    }

    @Test("A background over a border also backs the border glyphs so the box is one solid shape")
    func fillBacksBorder() {
        let node = Text("Hi").border(.primary).background(.blue).makeNode()
        let raw = NodeLayout.frame(of: node).lines
        // Every row — including the top/bottom border rows and the corners —
        // carries the fill background, leaving no gap at the edge.
        for line in raw {
            #expect(line.contains("\u{001B}[44m"))
        }
    }

    @Test("Border colour changes the escape output but not the glyph grid")
    func borderColour() {
        let plainNode = Text("Hi").border(.primary).makeNode()
        let colourNode = Text("Hi").border(.cyan).makeNode()
        // Same visible grid…
        #expect(plainLines(plainNode) == plainLines(colourNode))
        // …different raw ANSI (the colour header is present).
        #expect(NodeLayout.frame(of: plainNode).lines != NodeLayout.frame(of: colourNode).lines)
    }
}

@Suite("SwiftUI-shaped modifier behaviour")
struct SwiftUIParityModifierTests {
    private func plainLines(_ node: RenderNode) -> [String] {
        NodeLayout.frame(of: node).lines.map { TextMetrics.stripANSI($0) }
    }

    /// The SGR prefix a blue background emits.
    private let blueBackground = "\u{001B}[44m"

    @Test("shadow(radius:) grows the footprint on every side; x/y shift it")
    func shadowGeometry() {
        let card = Text("Card").border(.primary)
        let base = NodeLayout.measure(card.makeNode())

        // No radius and no offset is fully covered by the view — nothing to see.
        let invisible = NodeLayout.measure(card.shadow().makeNode())
        #expect(invisible == base)

        // A one-cell halo adds one cell on each of the four sides.
        let halo = NodeLayout.measure(card.shadow(radius: 1).makeNode())
        #expect(halo.width == base.width + 2)
        #expect(halo.height == base.height + 2)

        // A negative offset throws the shadow up and to the left instead.
        let upLeft = card.shadow(x: -1, y: -1).makeNode()
        #expect(NodeLayout.measure(upLeft).width == base.width + 1)
        #expect(NodeLayout.measure(upLeft).height == base.height + 1)
        let lines = plainLines(upLeft)
        // The content is pushed one cell right and one row down inside the
        // footprint, so the shadow never lands before the origin.
        #expect(lines[1].hasPrefix(" ╭────╮"))
        #expect(lines[2].hasPrefix(" │Card│"))

        // Offset plus radius: the overhang is the sum on the trailing side.
        let combined = NodeLayout.measure(card.shadow(radius: 1, x: 2, y: 1).makeNode())
        #expect(combined.width == base.width + 3)   // 2 + 1 right, 0 left
        #expect(combined.height == base.height + 2)  // 1 + 1 below, 0 above
    }

    @Test("A shadow paints only the cells the view does not cover")
    func shadowDoesNotLeakUnderContent() {
        let raw = NodeLayout.frame(of: Text("Hi").shadow(color: .blue, x: 1, y: 1).makeNode()).lines
        // A one-row view shifted by (1, 1) casts its shadow entirely on the
        // row below: row 0 is the untouched text, row 1 the shadow band.
        #expect(raw.count == 2)
        #expect(!raw[0].contains(blueBackground))
        #expect(raw[1].contains(blueBackground))
        #expect(TextMetrics.stripANSI(raw[1]).count == 3)
    }

    @Test("background(_:) after padding() paints the padding cells too")
    func backgroundCoversPadding() {
        let raw = NodeLayout.frame(of: Text("Hi").padding().background(.blue).makeNode()).lines
        // Three rows: padding above, content, padding below — every one blue.
        #expect(raw.count == 3)
        for line in raw { #expect(line.contains(blueBackground)) }
        // The padded row is painted edge to edge, so it starts with the colour.
        #expect(raw[0].hasPrefix(blueBackground))
    }

    @Test("background(_:) after frame() paints the frame's slack")
    func backgroundCoversFrameSlack() {
        let raw = NodeLayout.frame(of: Text("Hi").frame(width: 6, height: 2, alignment: .topLeading).background(.blue).makeNode()).lines
        #expect(raw.count == 2)
        // The empty second row is painted as well.
        #expect(raw[1].contains(blueBackground))
        // The visible grid is the frame's full size.
        let plain = raw.map { TextMetrics.stripANSI($0) }
        #expect(plain[0].count == 6)
    }

    @Test("background(_:) before padding() leaves the padding transparent")
    func backgroundInsidePadding() {
        let raw = NodeLayout.frame(of: Text("Hi").background(.blue).padding().makeNode()).lines
        #expect(raw.count == 3)
        #expect(!raw[0].contains(blueBackground))
        #expect(raw[1].contains(blueBackground))
    }

    @Test("padding() defaults to one cell on every edge; padding(.leading) pads one edge")
    func paddingDefaults() {
        let all = NodeLayout.measure(Text("Hi").padding().makeNode())
        #expect(all.width == 4)
        #expect(all.height == 3)
        let leading = NodeLayout.measure(Text("Hi").padding(.leading).makeNode())
        #expect(leading.width == 3)
        #expect(leading.height == 1)
        let two = NodeLayout.measure(Text("Hi").padding(2).makeNode())
        #expect(two.width == 6)
        #expect(two.height == 5)
    }

    @Test("foregroundColor(_:) is the older spelling of foregroundStyle(_:)")
    func foregroundColorAlias() {
        let a = Text("Hi").foregroundStyle(.red).makeNode()
        let b = Text("Hi").foregroundColor(.red).makeNode()
        #expect(a == b)
    }

    @Test("Divider() sized with .frame(width:) draws that many columns")
    func dividerFrameWidth() {
        let lines = plainLines(VStack {
            Text("Section A")
            Divider().frame(width: 5)
            Text("Section B")
        }.makeNode())
        #expect(lines[1].trimmingCharacters(in: .whitespaces) == "-----")
    }
}

#endif
