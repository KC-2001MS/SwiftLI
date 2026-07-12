//
//  ContentUnavailableView.swift
//  sclt
//
//  Created by Keisuke Chinone on 2026/07/12.
//

import ArgumentParser
import SwiftLI

/// A static catalogue of ``ContentUnavailableView``, rendered inline so the
/// output stays in the terminal scrollback.
struct ContentUnavailableCommand: InlineCommand {
    static let configuration = CommandConfiguration(
        commandName: "contentunavailable",
        abstract: "Display of ContentUnavailableView structure",
        discussion: """
        Command to check the display of the ContentUnavailableView structure:
        an empty-state view with an optional icon, a bold title, and an
        optional dimmed description
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    // No run() — the default inline session renders once and, with nothing
    // left to do, exits by itself.

    var body: some Scene {
        NavigationStack {
            Text("ContentUnavailableView(_ title:)")
                .forgroundColor(.cyan)
                .navigationTitle("ContentUnavailableView")

            ContentUnavailableView("No Data")

            Text("ContentUnavailableView(_ title:, image:)")
                .forgroundColor(.cyan)
                .padding(.top, 1)

            ContentUnavailableView("No Mail", image: "📭")

            Text("ContentUnavailableView(_ title:, image:, description:)")
                .forgroundColor(.cyan)
                .padding(.top, 1)

            ContentUnavailableView(
                "No Results",
                image: "🔍",
                description: "Try a different search term."
            )
        }
    }
}
