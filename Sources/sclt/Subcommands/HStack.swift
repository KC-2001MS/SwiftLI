//
//  HStack.swift
//
//
//  Created by Keisuke Chinone on 2024/05/27.
//

import ArgumentParser
import SwiftLI

struct HStackCommand: AsyncParsableCommand, ViewableCommand {
    static let configuration = CommandConfiguration(
        commandName: "hstack",
        abstract: "Display of HStack structure",
        discussion: """
        Command to check the display of HStack structure
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
            Text("HStack View")
                .background(Color.white)
                .forgroundColor(Color.blue)
                .bold()

            // Basic HStack
            Text("HStack { ... }")
                .forgroundColor(.cyan)
            HStack(spacing: 1) {
                Text("[")
                Text("Left").forgroundColor(.red)
                Text("|")
                Text("Center").forgroundColor(.green)
                Text("|")
                Text("Right").forgroundColor(.blue)
                Text("]")
            }
            Spacer()

            // HStack with dynamic color cycling
            Text("HStack with dynamic color:")
                .forgroundColor(.cyan)
            HStack(spacing: 2) {
                Text("A").forgroundColor(colors[colorIndex]).bold()
                Text("B").forgroundColor(colors[(colorIndex + 1) % colors.count]).bold()
                Text("C").forgroundColor(colors[(colorIndex + 2) % colors.count]).bold()
                Text("D").forgroundColor(colors[(colorIndex + 3) % colors.count]).bold()
                Text("E").forgroundColor(colors[(colorIndex + 4) % colors.count]).bold()
                Text("F").forgroundColor(colors[(colorIndex + 5) % colors.count]).bold()
            }
            Spacer()

            // HStack with spacing demo
            Text("HStack(spacing: \(step)):")
                .forgroundColor(.cyan)
            HStack(spacing: step) {
                Text("█").forgroundColor(.red)
                Text("█").forgroundColor(.green)
                Text("█").forgroundColor(.yellow)
                Text("█").forgroundColor(.blue)
                Text("█").forgroundColor(.magenta)
            }
            Spacer()

            // Alignment demo
            Text("HStack(alignment: .top):")
                .forgroundColor(.cyan)
            HStack(alignment: .top, spacing: 2) {
                Text("Short").forgroundColor(colors[colorIndex])
                Text("Also short").forgroundColor(colors[(colorIndex + 3) % colors.count])
            }
            Spacer()
            Text("HStack(alignment: .bottom):")
                .forgroundColor(.cyan)
            HStack(alignment: .bottom, spacing: 2) {
                Text("Short").forgroundColor(colors[colorIndex])
                Text("Also short").forgroundColor(colors[(colorIndex + 3) % colors.count])
            }
            Spacer()
        }
    }
}
