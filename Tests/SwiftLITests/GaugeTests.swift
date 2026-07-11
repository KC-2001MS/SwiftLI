//
//  GaugeTests.swift
//  SwiftLITests
//
//  Created by Keisuke Chinone on 2026/07/10.
//

#if swift(>=6.0)
import Testing
@_spi(RenderingInternals) @testable import SwiftLI
import Foundation

// MARK: - ProgressView graceful degradation

@Suite("Gauge Degradation Testing")
struct GaugeDegradationTests {
    private func plain(_ v: some View) -> String {
        TextMetrics.stripANSI(v.renderString())
    }

    private func config(width: Int, label: String = "") -> GaugeStyleConfiguration {
        GaugeStyleConfiguration(
            fractionCompleted: 0.5,
            width: width,
            filledCharacter: "\u{2588}",
            emptyCharacter: "\u{2591}",
            label: label.isEmpty ? nil : AnyView(Text(label))
        )
    }

    @Test("Bar keeps its gauge when there is room for it")
    func barShowsGauge() {
        let out = plain(BarGaugeStyle().makeBody(configuration: config(width: 10)))
        #expect(out.contains("["))
        #expect(out.contains("50%"))
    }

    @Test("An auto-sized gauge shrinks to its container's width")
    func gaugeShrinksToFrame() {
        let out = plain(Gauge(value: 0.5).frame(width: 24, alignment: .topLeading))
        let lines = out.components(separatedBy: "\n")
        // Instead of wrapping or being truncated with an ellipsis, the meter's
        // fillable region shortens so the whole gauge fits on one line.
        #expect(lines.count == 1)
        #expect(TextMetrics.visibleWidth(lines[0]) <= 24)
        #expect(lines[0].hasPrefix("["))
        #expect(lines[0].contains("50%"))
    }

    @Test("Bar collapses to a spinner glyph plus the label when width runs out")
    func barCollapsesToSpinner() {
        let out = plain(BarGaugeStyle().makeBody(configuration: config(width: 0, label: "Build")))
        #expect(!out.contains("["))
        #expect(!out.contains("\u{2588}"))
        #expect(out.contains("Build"))
        // The leading glyph is one of the spinner frames.
        #expect(ProgressSpinner.frames.contains(out.first!))
    }

    @Test("A collapsed-width bar with no label is a single spinner glyph")
    func negativeWidthIsBareSpinner() {
        let out = plain(BarGaugeStyle().makeBody(configuration: config(width: -3)))
        #expect(!out.contains("["))
        #expect(out.count == 1)
        #expect(ProgressSpinner.frames.contains(out.first!))
    }

    @Test("ProgressView renders a spinner frame chosen by its phase")
    func progressViewSpinner() {
        let out = plain(ProgressView("Loading", phase: 2))
        #expect(out.contains("Loading"))
        #expect(out.first == ProgressSpinner.character(for: 2))
    }

    @Test("The bar fills with 1/8-cell precision using left block elements")
    func subCellFill() {
        // Half of one cell → a left-half block, no empty remainder.
        #expect(GaugeFill.run(width: 1, fraction: 0.5, filled: "█", empty: "░").filled == "▌")
        // 1/8 of one cell → the thinnest left block.
        #expect(GaugeFill.run(width: 1, fraction: 0.125, filled: "█", empty: "░").filled == "▏")
        // 2.625 cells over width 4 → two full blocks + a five-eighths block.
        let r = GaugeFill.run(width: 4, fraction: 2.625 / 4.0, filled: "█", empty: "░")
        #expect(r.filled == "██▋")
        #expect(r.empty == "░")
        // A custom fill glyph falls back to whole-cell fill (no eighth blocks).
        #expect(GaugeFill.run(width: 4, fraction: 0.5, filled: "=", empty: "-").filled == "==")
    }
}

#endif
