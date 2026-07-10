//
//  Text.swift
//
//
//  Created by Keisuke Chinone on 2024/05/27.
//

import ArgumentParser
import SwiftLI

struct TextCommand: AsyncParsableCommand, FullScreenCommand {
    static let configuration = CommandConfiguration(
        commandName: "text",
        abstract: "Display of Text structure",
        discussion: """
        Command to check the display of Text structure
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    @State var isActive: Bool = false
    @State var colorIndex: Int = 0
    @State var message: String = "Hello, SwiftLI!"

    var colors: [Color] { [.red, .green, .yellow, .blue, .magenta, .cyan, .white] }
    var colorNames: [String] { ["red", "green", "yellow", "blue", "magenta", "cyan", "white"] }
    var messages: [String] { ["Hello, SwiftLI!", "Text changes!", "Dynamic body!", "Reactive CLI!"] }

    mutating func run() async throws {
        startBodyRendering()
        for i in 1...7 {
            try await Task.sleep(nanoseconds: 600_000_000)
            isActive = i % 2 == 1
            colorIndex = i % colors.count
            message = messages[i % messages.count]
        }
        stopBodyRendering()
    }

    var body: some View {
        Text("Text View")
            .background(Color.white)
            .forgroundColor(Color.blue)
            .bold()

        // Text content change demo
        HStack(spacing: 1) {
            Text("Text(_ content: String)")
                .forgroundColor(.cyan)
            Spacer(2)
            Text(message)
                .bold()
                .forgroundColor(colors[colorIndex])
        }

        // forgroundColor cycling
        HStack(spacing: 1) {
            Text("Text.forgroundColor(_ color: Color)")
                .forgroundColor(colors[colorIndex])
            Spacer(2)
            Text(".\(colorNames[colorIndex])")
                .fontWeight(.thin)
                .forgroundColor(colors[colorIndex])
        }

        // background color cycling
        HStack(spacing: 1) {
            Text("Text.background(_ color: Color)")
                .background(colors[colorIndex])
            Spacer(2)
            Text(".\(colorNames[colorIndex])")
                .fontWeight(.thin)
                .forgroundColor(.red)
        }

        // bold toggle
        Text("Text.bold()")
            .bold()

        HStack(spacing: 1) {
            Text("Text.bold(_ isActive: Bool)")
                .bold(isActive)
            Spacer(2)
            Text(isActive ? "true" : "false")
                .fontWeight(.thin)
                .forgroundColor(isActive ? .green : .red)
        }

        // fontWeight
        HStack(spacing: 1) {
            Text("Text.fontWeight(_ weight: Weight)")
                .fontWeight(.thin)
            Spacer(2)
            Text(".thin")
                .fontWeight(.thin)
                .forgroundColor(.red)
        }

        // italic toggle
        Text("Text.italic()")
            .italic()

        HStack(spacing: 1) {
            Text("Text.italic(_ isActive: Bool)")
                .italic(isActive)
            Spacer(2)
            Text(isActive ? "true" : "false")
                .fontWeight(.thin)
                .forgroundColor(isActive ? .green : .red)
        }

        // underline toggle
        Text("Text.underline()")
            .underline()

        HStack(spacing: 1) {
            Text("Text.underline(_ isActive: Bool)")
                .underline(isActive)
            Spacer(2)
            Text(isActive ? "true" : "false")
                .fontWeight(.thin)
                .forgroundColor(isActive ? .green : .red)
        }

        // blink
        HStack(spacing: 1) {
            Text("Text.blink(_ style: BlinkStyle)")
                .blink(.default)
            Spacer(2)
            Text(".default")
                .fontWeight(.thin)
                .forgroundColor(.red)
        }

        // hidden toggle
        Text("Text.hidden()")
            .hidden()

        HStack(spacing: 1) {
            Text("Text.hidden(_ isActive: Bool)")
                .hidden(isActive)
            Spacer(2)
            Text(isActive ? "true (invisible above)" : "false")
                .fontWeight(.thin)
                .forgroundColor(isActive ? .green : .red)
        }

        // strikethrough toggle
        Text("Text.strikethrough()")
            .strikethrough()

        HStack(spacing: 1) {
            Text("Text.strikethrough(_ isActive: Bool)")
                .strikethrough(isActive)
            Spacer(2)
            Text(isActive ? "true" : "false")
                .fontWeight(.thin)
                .forgroundColor(isActive ? .green : .red)
        }
    }
}
