//
//  Gauge.swift
//  sclt
//
//  Created by Keisuke Chinone on 2026/07/09.
//

import Foundation
import ArgumentParser
import SwiftLI

struct GaugeCommand: FullScreenCommand {
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

    @Environment(\.dismiss) var dismiss

    // No run() — the task in `body` animates the gauges, then dismisses.

    var body: some Scene {
        NavigationStack {
            let percent = Int((progress * 100).rounded())
            Text("Every style is driven live by the same value (\(percent)%)")
                .forgroundColor(.cyan)
                .navigationTitle("Gauge")
                .task {
                    for i in 1...100 {
                        try? await Task.sleep(nanoseconds: 30_000_000)
                        progress = Double(i) / 100.0
                    }
                    dismiss()
                }

            HStack(spacing: 1) {
                Text("Bar        ").forgroundColor(.red)
                Gauge(min: min, value: progress, max: max).frame(width: 30, alignment: .topLeading)
            }
                .padding(.top, 1)

            HStack(spacing: 1) {
                Text("Linear     ").forgroundColor(.red)
                Gauge(min: min, value: progress, max: max).frame(width: 30, alignment: .topLeading)
                    .gaugeStyle(LinearGaugeStyle())
            }

            HStack(spacing: 1) {
                Text("Percentage ").forgroundColor(.red)
                Gauge(min: min, value: progress, max: max).frame(width: 30, alignment: .topLeading)
                    .gaugeStyle(PercentageGaugeStyle())
            }

            Text("Labeled full width (label sits by the percentage):")
                .forgroundColor(.cyan)
                .padding(.top, 1)
            Gauge("Downloading", min: min, value: progress, max: max)
            Gauge("Extracting", min: min, value: progress, max: max)
                .gaugeStyle(LinearGaugeStyle())

            Divider()
                .padding(.top, 1)
            Text("Ctrl-C to quit").forgroundColor(.eight_bit(240))
        }
    }
}
