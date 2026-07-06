//
//  ProgressBar.swift
//
//
//  Created by Keisuke Chinone on 2024/05/27.
//

import Foundation
import ArgumentParser
import SwiftLI

struct ProgressBarCommand: AsyncParsableCommand, ViewableCommand {
    static let configuration = CommandConfiguration(
        commandName: "progressbar",
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
        Group {
            Text("ProgressView")
                .background(.white)
                .forgroundColor(.blue)
                .bold()

            Text("Animated bar (0% → 100%)")
                .forgroundColor(.cyan)

            ProgressView(min: min, value: progress, max: max, width: 40)

            Spacer()

            Text("Static snapshots — BarProgressViewStyle (default)")
                .forgroundColor(.cyan)

            Group {
                for pct in [0, 25, 50, 75, 100] {
                    HStack(spacing: 1) {
                        Text(String(format: "%3d%% ", pct))
                            .fontWeight(.thin)
                            .forgroundColor(.red)
                        ProgressView(min: min, value: Double(pct) / 100.0, max: max, width: 30)
                    }
                }
            }

            Spacer()

            Text("Static snapshots — LinearProgressViewStyle")
                .forgroundColor(.cyan)

            Group {
                for pct in [0, 25, 50, 75, 100] {
                    HStack(spacing: 1) {
                        Text(String(format: "%3d%% ", pct))
                            .fontWeight(.thin)
                            .forgroundColor(.red)
                        ProgressView(min: min, value: Double(pct) / 100.0, max: max, width: 30)
                            .progressViewStyle(LinearProgressViewStyle())
                    }
                }
            }

            Spacer()

            Text("Static snapshots — PercentageProgressViewStyle")
                .forgroundColor(.cyan)

            Group {
                for pct in [0, 25, 50, 75, 100] {
                    HStack(spacing: 1) {
                        Text(String(format: "%3d%% → ", pct))
                            .fontWeight(.thin)
                            .forgroundColor(.red)
                        ProgressView(min: min, value: Double(pct) / 100.0, max: max, width: 30)
                            .progressViewStyle(PercentageProgressViewStyle())
                    }
                }
            }

            Spacer()

            Text("Static snapshots — SpinnerProgressViewStyle")
                .forgroundColor(.cyan)

            Group {
                for pct in [0, 25, 50, 75, 100] {
                    HStack(spacing: 1) {
                        Text(String(format: "%3d%% ", pct))
                            .fontWeight(.thin)
                            .forgroundColor(.red)
                        ProgressView(min: min, value: Double(pct) / 100.0, max: max, width: 30)
                            .progressViewStyle(SpinnerProgressViewStyle(label: "Processing"))
                    }
                }
            }
        }
    }
}
