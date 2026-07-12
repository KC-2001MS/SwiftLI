//
//  Section.swift
//  sclt
//
//  Created by Keisuke Chinone on 2026/07/12.
//

import ArgumentParser
import SwiftLI

/// A static catalogue of ``Section`` and its four initializers, rendered
/// inline so the output stays in the terminal scrollback.
struct SectionCommand: InlineCommand {
    static let configuration = CommandConfiguration(
        commandName: "section",
        abstract: "Display of Section structure",
        discussion: """
        Command to check the display of the Section structure: a titled slice
        of content with an optional header and footer, as used inside Form
        and List
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    // No run() — the default inline session renders once and, with nothing
    // left to do, exits by itself.

    var body: some Scene {
        NavigationStack {
            Text("Section(_ title: LocalizedStringKey)")
                .forgroundColor(.cyan)
                .navigationTitle("Section")

            Section("Account") {
                Text("Name: Keisuke")
                Text("Plan: Free")
            }

            Text("Section(content:header:)")
                .forgroundColor(.cyan)
                .padding(.top, 1)

            Section {
                Text("Sound: On")
                Text("Badges: Off")
            } header: {
                Label("Notifications", unicodeImage: 0x1F514)
            }

            Text("Section(content:footer:)")
                .forgroundColor(.cyan)
                .padding(.top, 1)

            Section {
                Text("Auto-lock: 5 minutes")
            } footer: {
                Text("A shorter time uses less battery.")
            }

            Text("Section(content:header:footer:)")
                .forgroundColor(.cyan)
                .padding(.top, 1)

            Section {
                Text("Two-factor: Enabled")
            } header: {
                Text("Security")
            } footer: {
                Text("You can change this later.")
            }
        }
    }
}
