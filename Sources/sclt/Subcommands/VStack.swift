//
//  VStack.swift
//
//
//  Created by Keisuke Chinone on 2024/05/27.
//

import ArgumentParser
import SwiftLI

/// A static catalogue of ``VStack``, rendered inline so the output stays in
/// the terminal scrollback.
struct VStackCommand: InlineCommand {
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

    // No run() — the default inline session renders once and, with nothing
    // left to do, exits by itself.

    var body: some Scene {
        NavigationStack {
            // Basic VStack
            Text("VStack { ... }")
                .forgroundColor(.cyan)
                .navigationTitle("VStack")
            VStack {
                Text("Row 1").forgroundColor(.red)
                Text("Row 2").forgroundColor(.green)
                Text("Row 3").forgroundColor(.blue)
            }

            // VStack alignment: leading vs trailing
                .padding(.top, 1)
            Text("VStack(alignment: .leading):")
                .forgroundColor(.cyan)
            VStack(alignment: .leading) {
                Text("Short").forgroundColor(.red)
                Text("Much longer text").forgroundColor(.yellow)
                Text("Med length").forgroundColor(.magenta)
            }
            Text("VStack(alignment: .trailing):")
                .forgroundColor(.cyan)
                .padding(.top, 1)
            VStack(alignment: .trailing) {
                Text("Short").forgroundColor(.red)
                Text("Much longer text").forgroundColor(.yellow)
                Text("Med length").forgroundColor(.magenta)
            }

            // Nested: VStack { HStack }
                .padding(.top, 1)
            Text("VStack(spacing: 1) { HStack { ... } }:")
                .forgroundColor(.cyan)
            VStack(spacing: 1) {
                HStack(spacing: 1) {
                    Text("[")
                    Text("Top-Left").forgroundColor(.red)
                    Text("|")
                    Text("Top-Right").forgroundColor(.blue)
                    Text("]")
                }
                HStack(spacing: 1) {
                    Text("[")
                    Text("Bottom-Left").forgroundColor(.green)
                    Text("|")
                    Text("Bottom-Right").forgroundColor(.magenta)
                    Text("]")
                }
            }
        }
    }
}
