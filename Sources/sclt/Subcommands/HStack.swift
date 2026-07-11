//
//  HStack.swift
//
//
//  Created by Keisuke Chinone on 2024/05/27.
//

import ArgumentParser
import SwiftLI

/// A static catalogue of ``HStack``, rendered inline so the output stays in
/// the terminal scrollback.
struct HStackCommand: InlineCommand {
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

    // No run() — the default inline session renders once and, with nothing
    // left to do, exits by itself.

    var body: some Scene {
        NavigationStack {
            // Basic HStack
            Text("HStack { ... }")
                .forgroundColor(.cyan)
                .navigationTitle("HStack")
            HStack(spacing: 1) {
                Text("[")
                Text("Left").forgroundColor(.red)
                Text("|")
                Text("Center").forgroundColor(.green)
                Text("|")
                Text("Right").forgroundColor(.blue)
                Text("]")
            }

            // Spacing demo
                .padding(.top, 1)
            Text("HStack(spacing: 0):")
                .forgroundColor(.cyan)
            HStack(spacing: 0) {
                Text("█").forgroundColor(.red)
                Text("█").forgroundColor(.green)
                Text("█").forgroundColor(.yellow)
                Text("█").forgroundColor(.blue)
                Text("█").forgroundColor(.magenta)
            }
            Text("HStack(spacing: 3):")
                .forgroundColor(.cyan)
            HStack(spacing: 3) {
                Text("█").forgroundColor(.red)
                Text("█").forgroundColor(.green)
                Text("█").forgroundColor(.yellow)
                Text("█").forgroundColor(.blue)
                Text("█").forgroundColor(.magenta)
            }

            // Alignment demo
                .padding(.top, 1)
            Text("HStack(alignment: .top):")
                .forgroundColor(.cyan)
            HStack(alignment: .top, spacing: 2) {
                Text("Short").forgroundColor(.red)
                Text("Also short").forgroundColor(.blue)
            }
            Text("HStack(alignment: .bottom):")
                .forgroundColor(.cyan)
                .padding(.top, 1)
            HStack(alignment: .bottom, spacing: 2) {
                Text("Short").forgroundColor(.red)
                Text("Also short").forgroundColor(.blue)
            }
        }
    }
}
