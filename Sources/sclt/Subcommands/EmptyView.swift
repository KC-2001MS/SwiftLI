//
//  EmptyView.swift
//  sclt
//
//  Created by Keisuke Chinone on 2026/07/12.
//

import ArgumentParser
import SwiftLI

/// A static catalogue of ``EmptyView``, rendered inline so the output stays
/// in the terminal scrollback.
struct EmptyViewCommand: InlineCommand {
    static let configuration = CommandConfiguration(
        commandName: "emptyview",
        abstract: "Display of EmptyView structure",
        discussion: """
        Command to check the display of the EmptyView structure: a view that
        renders nothing and occupies no space, useful as a placeholder where
        a view is required but nothing should show
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    // No run() — the default inline session renders once and, with nothing
    // left to do, exits by itself.

    var body: some Scene {
        NavigationStack {
            Text("EmptyView()")
                .forgroundColor(.cyan)
                .navigationTitle("EmptyView")

            // The brackets sit flush together: the EmptyView between them
            // contributes no cells at all.
            HStack(spacing: 0) {
                Text("[")
                EmptyView()
                Text("] ← an EmptyView sits between the brackets")
                    .forgroundColor(.eight_bit(245))
            }

            // Unlike .hidden(), which blanks a view but keeps its width.
            HStack(spacing: 0) {
                Text("[")
                Text("hidden").hidden()
                Text("] ← .hidden() keeps the width for comparison")
                    .forgroundColor(.eight_bit(245))
            }
        }
    }
}
