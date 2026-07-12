//
//  ProgressView.swift
//
//
//  Created by Keisuke Chinone on 2024/05/27.
//

import Foundation
import ArgumentParser
import SwiftLI

struct ProgressViewCommand: FullScreenCommand {
    static let configuration = CommandConfiguration(
        commandName: "progressview",
        abstract: "Display of the indeterminate ProgressView spinner",
        discussion: """
        ProgressView is an indeterminate activity indicator — a spinning glyph
        that signals work is happening without reporting a value. Advance its
        `phase` over time to animate it. For a determinate meter, see `gauge`.
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    @State var tick: Int = 0

    @Environment(\.dismiss) var dismiss

    // No run() — the task in `body` animates the spinner, then dismisses.

    var body: some Scene {
        NavigationStack {
            Text("An indeterminate spinner — phase advances each tick (\(tick))")
                .forgroundColor(.cyan)
                .navigationTitle("ProgressView")
                .task {
                    for _ in 0..<200 {
                        try? await Task.sleep(nanoseconds: 80_000_000)
                        tick += 1
                    }
                    dismiss()
                }

            HStack(spacing: 1) {
                Text("With label ").forgroundColor(.red)
                ProgressView("Loading", phase: tick)
            }
                .padding(.top, 1)

            HStack(spacing: 1) {
                Text("Bare glyph ").forgroundColor(.red)
                ProgressView(phase: tick)
            }

            // ProgressView-specific modifier: progressViewStyle picks the
            // indicator's appearance (.automatic is the cyan spinner).
            HStack(spacing: 1) {
                Text(".progressViewStyle(.automatic)").forgroundColor(.red)
                ProgressView("Styled", phase: tick)
                    .progressViewStyle(.automatic)
            }

            Divider()
                .padding(.top, 1)
            Text("Ctrl-C to quit").forgroundColor(.eight_bit(240))
        }
    }
}
