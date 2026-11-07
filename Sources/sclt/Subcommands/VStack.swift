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
                .foregroundStyle(.cyan)
                .navigationTitle("VStack")
            VStack {
                Text("Row 1").foregroundStyle(.red)
                Text("Row 2").foregroundStyle(.green)
                Text("Row 3").foregroundStyle(.blue)
            }

            // VStack alignment: leading vs trailing
                .padding(.top, 1)
            Text("VStack(alignment: .leading):")
                .foregroundStyle(.cyan)
            VStack(alignment: .leading) {
                Text("Short").foregroundStyle(.red)
                Text("Much longer text").foregroundStyle(.yellow)
                Text("Med length").foregroundStyle(.magenta)
            }
            Text("VStack(alignment: .trailing):")
                .foregroundStyle(.cyan)
                .padding(.top, 1)
            VStack(alignment: .trailing) {
                Text("Short").foregroundStyle(.red)
                Text("Much longer text").foregroundStyle(.yellow)
                Text("Med length").foregroundStyle(.magenta)
            }

            // Nested: VStack { HStack }
                .padding(.top, 1)
            Text("VStack(spacing: 1) { HStack { ... } }:")
                .foregroundStyle(.cyan)
            VStack(spacing: 1) {
                HStack(spacing: 1) {
                    Text("[")
                    Text("Top-Left").foregroundStyle(.red)
                    Text("|")
                    Text("Top-Right").foregroundStyle(.blue)
                    Text("]")
                }
                HStack(spacing: 1) {
                    Text("[")
                    Text("Bottom-Left").foregroundStyle(.green)
                    Text("|")
                    Text("Bottom-Right").foregroundStyle(.magenta)
                    Text("]")
                }
            }
        }
    }
}
