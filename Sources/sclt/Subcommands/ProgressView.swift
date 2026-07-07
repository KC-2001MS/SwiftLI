//
//  ProgressView.swift
//
//
//  Created by Keisuke Chinone on 2024/05/27.
//

import Foundation
import ArgumentParser
import SwiftLI

struct ProgressViewCommand: AsyncParsableCommand, FullScreenViewableCommand {
    static let configuration = CommandConfiguration(
        commandName: "progressview",
        abstract: "Display of ProgressView structure",
        discussion: """
        Command to check the display of ProgressView structure
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
        return Group {
            Text("ProgressView")
                .background(.white)
                .forgroundColor(.blue)
                .bold()

            Text("Every style is driven live by the same value (\(percent)%)")
                .forgroundColor(.cyan)

            Spacer()

            // All four styles animate from the same `progress` state, so each
            // one visibly moves as the value changes. The leading text is a
            // row identifier; the ProgressView's own `label` appears in the
            // trailing status area (where the percentage is shown).
            HStack(spacing: 1) {
                Text("Bar        ").forgroundColor(.red)
                ProgressView(min: min, value: progress, max: max, width: 30)
            }

            HStack(spacing: 1) {
                Text("Linear     ").forgroundColor(.red)
                ProgressView(min: min, value: progress, max: max, width: 30)
                    .progressViewStyle(LinearProgressViewStyle())
            }

            HStack(spacing: 1) {
                Text("Percentage ").forgroundColor(.red)
                ProgressView(min: min, value: progress, max: max, width: 30)
                    .progressViewStyle(PercentageProgressViewStyle())
            }

            HStack(spacing: 1) {
                Text("Spinner    ").forgroundColor(.red)
                ProgressView(min: min, value: progress, max: max, width: 30)
                    .progressViewStyle(SpinnerProgressViewStyle(label: "Processing"))
            }

            Spacer()

            // The `label` is drawn in the trailing status area, right where the
            // percentage sits. Width unspecified → auto-sizes to the full
            // terminal width (label included) and follows the window on resize.
            // As the width collapses, the gauge shrinks and finally becomes a
            // one-character spinner plus the label.
            Text("Labeled full width (label sits by the percentage):")
                .forgroundColor(.cyan)
            ProgressView("Downloading", min: min, value: progress, max: max)
            ProgressView("Extracting", min: min, value: progress, max: max)
                .progressViewStyle(LinearProgressViewStyle())
        }
    }
}
