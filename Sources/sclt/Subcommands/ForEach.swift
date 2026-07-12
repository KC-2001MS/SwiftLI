//
//  ForEach.swift
//  sclt
//
//  Created by Keisuke Chinone on 2026/07/12.
//

import ArgumentParser
import SwiftLI

/// A static catalogue of ``ForEach``, rendered inline so the output stays in
/// the terminal scrollback.
struct ForEachCommand: InlineCommand {
    static let configuration = CommandConfiguration(
        commandName: "foreach",
        abstract: "Display of ForEach structure",
        discussion: """
        Command to check the display of the ForEach structure: one child per
        element of a collection, emitted transparently into the enclosing
        stack
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    private var fruits: [String] { ["Apple", "Banana", "Cherry"] }

    // No run() — the default inline session renders once and, with nothing
    // left to do, exits by itself.

    var body: some Scene {
        NavigationStack {
            Text("ForEach(_ data:) over a collection")
                .forgroundColor(.cyan)
                .navigationTitle("ForEach")

            ForEach(fruits) { fruit in
                Text("• \(fruit)")
            }

            Text("ForEach(0..<5) over a range, inside an HStack")
                .forgroundColor(.cyan)
                .padding(.top, 1)

            HStack(spacing: 1) {
                ForEach(0..<5) { i in
                    Text("\(i)")
                }
            }

            // A modifier applied to the whole ForEach cascades onto every
            // generated child.
            Text("Style cascade: .forgroundColor(.green) on the ForEach")
                .forgroundColor(.cyan)
                .padding(.top, 1)

            ForEach(fruits) { fruit in
                Text("• \(fruit)")
            }
                .forgroundColor(.green)
        }
    }
}
