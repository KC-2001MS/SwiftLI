//
//  Text.swift
//
//
//  Created by Keisuke Chinone on 2024/05/27.
//

import ArgumentParser
import SwiftLI

/// A static catalogue of ``Text`` and its modifiers, rendered inline so the
/// output stays in the terminal scrollback.
struct TextCommand: InlineCommand {
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

    // No run() — the default inline session renders once and, with nothing
    // left to do, exits by itself.

    var body: some Scene {
        NavigationStack {
            HStack(spacing: 1) {
                Text("Text(_ content: String)")
                    .forgroundColor(.cyan)
                Spacer(minLength: 2)
                Text("Hello, SwiftLI!")
                    .bold()
            }
            .navigationTitle("Text")

            HStack(spacing: 1) {
                Text("Text.forgroundColor(_ color: Color)")
                    .forgroundColor(.red)
                Spacer(minLength: 2)
                Text(".red")
                    .fontWeight(.thin)
                    .forgroundColor(.red)
            }

            HStack(spacing: 1) {
                Text("Text.background(_ color: Color)")
                    .background(.red)
                Spacer(minLength: 2)
                Text(".red")
                    .fontWeight(.thin)
                    .forgroundColor(.red)
            }

            Text("Text.bold()")
                .bold()

            HStack(spacing: 1) {
                Text("Text.bold(_ isActive: Bool)")
                    .bold(false)
                Spacer(minLength: 2)
                Text("false")
                    .fontWeight(.thin)
                    .forgroundColor(.red)
            }

            HStack(spacing: 1) {
                Text("Text.fontWeight(_ weight: Weight)")
                    .fontWeight(.thin)
                Spacer(minLength: 2)
                Text(".thin")
                    .fontWeight(.thin)
                    .forgroundColor(.red)
            }

            Text("Text.italic()")
                .italic()

            HStack(spacing: 1) {
                Text("Text.italic(_ isActive: Bool)")
                    .italic(false)
                Spacer(minLength: 2)
                Text("false")
                    .fontWeight(.thin)
                    .forgroundColor(.red)
            }

            Text("Text.underline()")
                .underline()

            HStack(spacing: 1) {
                Text("Text.underline(_ isActive: Bool)")
                    .underline(false)
                Spacer(minLength: 2)
                Text("false")
                    .fontWeight(.thin)
                    .forgroundColor(.red)
            }

            HStack(spacing: 1) {
                Text("Text.blink(_ style: BlinkStyle)")
                    .blink(.default)
                Spacer(minLength: 2)
                Text(".default")
                    .fontWeight(.thin)
                    .forgroundColor(.red)
            }

            Text("Text.hidden()")
                .hidden()

            HStack(spacing: 1) {
                Text("Text.hidden(_ isActive: Bool)")
                    .hidden(false)
                Spacer(minLength: 2)
                Text("false")
                    .fontWeight(.thin)
                    .forgroundColor(.red)
            }

            Text("Text.strikethrough()")
                .strikethrough()

            HStack(spacing: 1) {
                Text("Text.strikethrough(_ isActive: Bool)")
                    .strikethrough(false)
                Spacer(minLength: 2)
                Text("false")
                    .fontWeight(.thin)
                    .forgroundColor(.red)
            }
        }
    }
}
