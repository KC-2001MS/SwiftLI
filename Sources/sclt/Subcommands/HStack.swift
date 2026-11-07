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
                .foregroundStyle(.cyan)
                .navigationTitle("HStack")
            HStack(spacing: 1) {
                Text("[")
                Text("Left").foregroundStyle(.red)
                Text("|")
                Text("Center").foregroundStyle(.green)
                Text("|")
                Text("Right").foregroundStyle(.blue)
                Text("]")
            }

            // Spacing demo
                .padding(.top, 1)
            Text("HStack(spacing: 0):")
                .foregroundStyle(.cyan)
            HStack(spacing: 0) {
                Text("█").foregroundStyle(.red)
                Text("█").foregroundStyle(.green)
                Text("█").foregroundStyle(.yellow)
                Text("█").foregroundStyle(.blue)
                Text("█").foregroundStyle(.magenta)
            }
            Text("HStack(spacing: 3):")
                .foregroundStyle(.cyan)
            HStack(spacing: 3) {
                Text("█").foregroundStyle(.red)
                Text("█").foregroundStyle(.green)
                Text("█").foregroundStyle(.yellow)
                Text("█").foregroundStyle(.blue)
                Text("█").foregroundStyle(.magenta)
            }

            // Alignment demo
                .padding(.top, 1)
            Text("HStack(alignment: .top):")
                .foregroundStyle(.cyan)
            HStack(alignment: .top, spacing: 2) {
                Text("Short").foregroundStyle(.red)
                Text("Also short").foregroundStyle(.blue)
            }
            Text("HStack(alignment: .bottom):")
                .foregroundStyle(.cyan)
                .padding(.top, 1)
            HStack(alignment: .bottom, spacing: 2) {
                Text("Short").foregroundStyle(.red)
                Text("Also short").foregroundStyle(.blue)
            }
        }
    }
}
