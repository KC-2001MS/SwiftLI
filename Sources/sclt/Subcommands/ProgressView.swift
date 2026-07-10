//
//  ProgressView.swift
//
//
//  Created by Keisuke Chinone on 2024/05/27.
//

import Foundation
import ArgumentParser
import SwiftLI

struct ProgressViewCommand: AsyncParsableCommand, FullScreenCommand {
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

    mutating func run() async throws {
        startBodyRendering()
        for _ in 0..<200 {
            try await Task.sleep(nanoseconds: 80_000_000)
            tick += 1
        }
        stopBodyRendering()
    }

    var body: some View {
        Text("ProgressView")
            .background(.white)
            .forgroundColor(.blue)
            .bold()

        Text("An indeterminate spinner — phase advances each tick (\(tick))")
            .forgroundColor(.cyan)

        Spacer()

        HStack(spacing: 1) {
            Text("With label ").forgroundColor(.red)
            ProgressView("Loading", phase: tick)
        }

        HStack(spacing: 1) {
            Text("Bare glyph ").forgroundColor(.red)
            ProgressView(phase: tick)
        }

        Spacer()
        Divider()
        Text("Ctrl-C to quit").forgroundColor(.eight_bit(240))
    }
}
