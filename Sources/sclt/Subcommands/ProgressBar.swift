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
        abstract: "Display of ProgressBar structure",
        discussion: """
        Command to check the display of ProgressBar structure
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
            Text("ProgressBar View")
                .background(.white)
                .forgroundColor(.blue)
                .bold()

            Text("Animated bar (0% → 100%)")
                .forgroundColor(.cyan)

            ProgressBar(min: min, value: progress, max: max, width: 40)

            Spacer()

            Text("Static snapshots")
                .forgroundColor(.cyan)

            Group {
                for pct in [0, 25, 50, 75, 100] {
                    HStack(spacing: 1) {
                        Text(String(format: "%3d%% ", pct))
                            .fontWeight(.thin)
                            .forgroundColor(.red)
                        ProgressBar(min: min, value: Double(pct) / 100.0, max: max, width: 30)
                    }
                }
            }
        }
    }
}
