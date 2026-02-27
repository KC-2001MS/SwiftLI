//
//  VStack.swift
//
//
//  Created by Keisuke Chinone on 2024/05/27.
//

import ArgumentParser
import SwiftLI

struct VStackCommand: AsyncParsableCommand, ViewableCommand {
    static let configuration = CommandConfiguration(
        commandName: "vstack",
        abstract: "Display of VStack structure",
        discussion: """
        Command to check the display of VStack structure
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    @State var colorIndex: Int = 0
    @State var step: Int = 0

    var colors: [Color] { [.red, .green, .yellow, .blue, .magenta, .cyan] }

    mutating func run() async throws {
        startBodyRendering()
        for i in 1...6 {
            try await Task.sleep(nanoseconds: 600_000_000)
            colorIndex = i % colors.count
            step = i
        }
        stopBodyRendering()
    }

    var body: some View {
        Group {
            Text("VStack View")
                .background(Color.white)
                .forgroundColor(Color.blue)
                .bold()

            // Basic VStack
            Text("VStack { ... }")
                .forgroundColor(.cyan)
            VStack {
                Text("Row 1").forgroundColor(.red)
                Text("Row 2").forgroundColor(.green)
                Text("Row 3").forgroundColor(.blue)
            }
            Spacer()

            // VStack with dynamic color
            Text("VStack with dynamic color:")
                .forgroundColor(.cyan)
            VStack {
                Text("■ Alpha").forgroundColor(colors[colorIndex]).bold()
                Text("■ Beta").forgroundColor(colors[(colorIndex + 1) % colors.count]).bold()
                Text("■ Gamma").forgroundColor(colors[(colorIndex + 2) % colors.count]).bold()
            }
            Spacer()

            // VStack alignment: leading vs trailing
            Text("VStack(alignment: .leading):")
                .forgroundColor(.cyan)
            VStack(alignment: .leading) {
                Text("Short").forgroundColor(colors[colorIndex])
                Text("Much longer text").forgroundColor(colors[(colorIndex + 2) % colors.count])
                Text("Med length").forgroundColor(colors[(colorIndex + 4) % colors.count])
            }
            Spacer()
            Text("VStack(alignment: .trailing):")
                .forgroundColor(.cyan)
            VStack(alignment: .trailing) {
                Text("Short").forgroundColor(colors[colorIndex])
                Text("Much longer text").forgroundColor(colors[(colorIndex + 2) % colors.count])
                Text("Med length").forgroundColor(colors[(colorIndex + 4) % colors.count])
            }
            Spacer()

            // Nested: VStack { HStack }
            Text("VStack(spacing: 1) { HStack { ... } }:")
                .forgroundColor(.cyan)
            VStack(spacing: 1) {
                HStack(spacing: 1) {
                    Text("[")
                    Text("Top-Left").forgroundColor(colors[colorIndex])
                    Text("|")
                    Text("Top-Right").forgroundColor(colors[(colorIndex + 3) % colors.count])
                    Text("]")
                }
                HStack(spacing: 1) {
                    Text("[")
                    Text("Bottom-Left").forgroundColor(colors[(colorIndex + 1) % colors.count])
                    Text("|")
                    Text("Bottom-Right").forgroundColor(colors[(colorIndex + 4) % colors.count])
                    Text("]")
                }
            }
            Spacer()
        }
    }
}
