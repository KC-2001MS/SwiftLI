//
//  Spacer.swift
//  
//  
//  Created by Keisuke Chinone on 2024/05/28.
//

import ArgumentParser
import SwiftLI

struct SpacerCommand: AsyncParsableCommand, FullScreenCommand {
    static let configuration = CommandConfiguration(
        commandName: "spacer",
        abstract: "Display of Spacer structure",
        discussion: """
        Command to check the display of Spacer structure
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    @State var count: Int = 1

    mutating func run() async throws {
        startBodyRendering()
        for i in 1...4 {
            try await Task.sleep(nanoseconds: 600_000_000)
            count = i
        }
        stopBodyRendering()
    }

    var body: some View {
        Text("Spacer View")
            .background(Color.white)
            .forgroundColor(Color.blue)
            .bold()

        // Vertical spacer demo: Spacer() inserts one blank row in VStack
        Text("init()")
            .forgroundColor(Color.cyan)

        HStack(spacing: 1) {
            Spacer(1)
            Text("← Spacer()  (1 space)")
                .fontWeight(.thin)
                .forgroundColor(.red)
        }

        Spacer()

        // Horizontal spacer demo: Spacer(count) in HStack
        HStack(spacing: 1) {
            Text("init(_ count: Int)")
                .forgroundColor(Color.cyan)
            Spacer(1)
            Text("\(count)")
                .fontWeight(.thin)
                .forgroundColor(.red)
        }

        HStack(spacing: 0) {
            Spacer(count)
            Text("← Spacer(\(count))")
                .fontWeight(.thin)
                .forgroundColor(.red)
        }
    }
}
