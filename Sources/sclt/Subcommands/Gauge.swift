//
//  Gauge.swift
//  sclt
//
//  Created by Keisuke Chinone on 2026/07/09.
//

import Foundation
import ArgumentParser
import SwiftLI

struct GaugeCommand: AsyncParsableCommand, FullScreenCommand {
    static let configuration = CommandConfiguration(
        commandName: "gauge",
        abstract: "Display of Gauge structure and styles",
        discussion: """
        Gauge is a determinate meter driven by a value in a range. Each built-in
        GaugeStyle (bar, linear, percentage) animates from the same live value.
        Ctrl-C quits.
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    @State var progress: Double = 0.0

    var min: Double { 0.0 }
    var max: Double { 1.0 }

    mutating func run() async throws {
        startBodyRendering()
        for i in 1...100 {
            try await Task.sleep(nanoseconds: 30_000_000)
            progress = Double(i) / 100.0
        }
        stopBodyRendering()
    }

    var body: some View {
        let percent = Int((progress * 100).rounded())
        Text("Gauge")
            .background(.white)
            .forgroundColor(.blue)
            .bold()

        Text("Every style is driven live by the same value (\(percent)%)")
            .forgroundColor(.cyan)

        Spacer()

        HStack(spacing: 1) {
            Text("Bar        ").forgroundColor(.red)
            Gauge(min: min, value: progress, max: max, width: 30)
        }

        HStack(spacing: 1) {
            Text("Linear     ").forgroundColor(.red)
            Gauge(min: min, value: progress, max: max, width: 30)
                .gaugeStyle(LinearGaugeStyle())
        }

        HStack(spacing: 1) {
            Text("Percentage ").forgroundColor(.red)
            Gauge(min: min, value: progress, max: max, width: 30)
                .gaugeStyle(PercentageGaugeStyle())
        }

        Spacer()

        Text("Labeled full width (label sits by the percentage):")
            .forgroundColor(.cyan)
        Gauge("Downloading", min: min, value: progress, max: max)
        Gauge("Extracting", min: min, value: progress, max: max)
            .gaugeStyle(LinearGaugeStyle())

        Spacer()
        Divider()
        Text("Ctrl-C to quit").forgroundColor(.eight_bit(240))
    }
}
