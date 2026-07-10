//
//  Divider.swift
//
//  
//  Created by Keisuke Chinone on 2024/05/29.
//

import ArgumentParser
import SwiftLI

struct DividerCommand: AsyncParsableCommand, FullScreenCommand {
    static let configuration = CommandConfiguration(
        commandName: "divider",
        abstract: "Display of Divider structure",
        discussion: """
        Command to check the display of Divider structure
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    @State var count: Int = 1

    mutating func run() async throws {
        startBodyRendering()
        for i in 1...10 {
            try await Task.sleep(nanoseconds: 400_000_000)
            count = i
        }
        stopBodyRendering()
    }

    var body: some View {
        Text("Divider View")
            .background(Color.white)
            .forgroundColor(Color.blue)
            .bold()

        // Full-width divider: no count → spans the whole terminal and
        // follows the window as it is resized.
        Text("Divider() full width (resize the terminal to see it follow):")
            .forgroundColor(.cyan)
        Divider()
        Spacer()

        // Horizontal divider (VStack context)
        Text("Divider() in VStack (horizontal):")
            .forgroundColor(.cyan)
        VStack {
            Text("Section A").forgroundColor(.green)
            Divider(count)
            Text("Section B").forgroundColor(.yellow)
        }
        Spacer()

        // Vertical divider (HStack context)
        Text("Divider() in HStack (vertical):")
            .forgroundColor(.cyan)
        HStack(spacing: 1) {
            Text("Left").forgroundColor(.red)
            Divider()
            Text("Right").forgroundColor(.blue)
        }
        Spacer()

        // lineStyle demo
        Text("Divider().lineStyle(.double_line):")
            .forgroundColor(.cyan)
        VStack {
            Text("Above").forgroundColor(.magenta)
            Divider(count).lineStyle(.double_line)
            Text("Below").forgroundColor(.cyan)
        }
        Spacer()
    }
}
