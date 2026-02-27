//
//  Group.swift
//
//  
//  Created by Keisuke Chinone on 2024/05/28.
//

import ArgumentParser
import SwiftLI

struct GroupCommand: AsyncParsableCommand, ViewableCommand {
    static let configuration = CommandConfiguration(
        commandName: "group",
        abstract: "Display of Group structure",
        discussion: """
        Command to check the display of Group structure
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    @State var isActive: Bool = false

    mutating func run() async throws {
        startBodyRendering()
        for _ in 0..<3 {
            try await Task.sleep(nanoseconds: 800_000_000)
            isActive.toggle()
        }
        stopBodyRendering()
    }

    var body: some View {
        Group {
            Text("Group View")
                .background(Color.white)
                .forgroundColor(Color.blue)
                .bold()

            HStack(spacing: 1) {
                Text("Group(@ViewBuilder contents: () -> [View])")
                    .forgroundColor(isActive ? .green : .cyan)
                Spacer(1)
                Text(isActive ? "active" : "inactive")
                    .fontWeight(.thin)
                    .forgroundColor(isActive ? .green : .red)
            }

            Group {
                Text("Group")
            }
        }
    }
}
