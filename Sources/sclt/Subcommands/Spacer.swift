//
//  Spacer.swift
//  
//  
//  Created by Keisuke Chinone on 2024/05/28.
//

import ArgumentParser
import SwiftLI

/// A static catalogue of ``Spacer``, rendered inline so the output stays in
/// the terminal scrollback.
struct SpacerCommand: InlineCommand {
    static let configuration = CommandConfiguration(
        commandName: "spacer",
        abstract: "Display of Spacer structure",
        discussion: """
        Command to check the display of Spacer structure
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    // No run() — the default inline session renders once and, with nothing
    // left to do, exits by itself.

    var body: some Scene {
        NavigationStack {
            // Horizontal spacer demo: Spacer() in an HStack expands to the
            // available width, pushing its neighbours to opposite edges.
            Text("init()")
                .forgroundColor(Color.cyan)
                .navigationTitle("Spacer")

            HStack(spacing: 0) {
                Text("Left")
                    .forgroundColor(.red)
                Spacer()
                Text("Right ← Spacer() fills the row")
                    .fontWeight(.thin)
                    .forgroundColor(.red)
            }

            // minLength sets the floor the flexible space never shrinks below.
            // (A bare Spacer() is no longer a one-line separator: vertically it
            // expands to fill the available height, pushing views apart.)
            Text("init(minLength: Int?)")
                .forgroundColor(Color.cyan)
                .padding(.top, 1)

            HStack(spacing: 0) {
                Text("Left")
                    .forgroundColor(.red)
                Spacer(minLength: 4)
                Text("Right ← at least 4 columns")
                    .fontWeight(.thin)
                    .forgroundColor(.red)
            }

            // Spacer-specific modifier: background paints the flexible gap
            // itself, making the space the spacer claims visible.
            Text("Spacer.background(_ color: Color)")
                .forgroundColor(Color.cyan)
                .padding(.top, 1)

            HStack(spacing: 0) {
                Text("Left")
                    .forgroundColor(.red)
                Spacer()
                    .background(.blue)
                Text("Right ← the gap is painted blue")
                    .fontWeight(.thin)
                    .forgroundColor(.red)
            }
        }
    }
}
