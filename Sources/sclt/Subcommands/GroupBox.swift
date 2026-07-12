//
//  GroupBox.swift
//  sclt
//
//  Created by Keisuke Chinone on 2026/07/12.
//

import ArgumentParser
import SwiftLI

/// A static catalogue of ``GroupBox`` and its ``GroupBox/groupBoxStyle(_:)``
/// modifier, rendered inline so the output stays in the terminal scrollback.
struct GroupBoxCommand: InlineCommand {
    static let configuration = CommandConfiguration(
        commandName: "groupbox",
        abstract: "Display of GroupBox structure",
        discussion: """
        Command to check the display of the GroupBox structure: a titled,
        bordered container, and its GroupBox-specific groupBoxStyle modifier
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    // No run() — the default inline session renders once and, with nothing
    // left to do, exits by itself.

    var body: some Scene {
        NavigationStack {
            Text("GroupBox(_ title: LocalizedStringKey?)")
                .forgroundColor(.cyan)
                .navigationTitle("GroupBox")

            GroupBox("Network") {
                Text("Status: Connected")
                Text("Latency: 24 ms")
            }

            Text("GroupBox { } — no title")
                .forgroundColor(.cyan)
                .padding(.top, 1)

            GroupBox {
                Text("Grouped content without a heading.")
            }

            // GroupBox-specific modifier: groupBoxStyle chooses how the title
            // and content are composed. `.automatic` is the padded rounded
            // border; a custom GroupBoxStyle can drop the border entirely.
            Text("GroupBox.groupBoxStyle(_ newStyle: GroupBoxStyle)")
                .forgroundColor(.cyan)
                .padding(.top, 1)

            GroupBox("Default (.automatic)") {
                Text("Bold title in a padded rounded border.")
            }
                .groupBoxStyle(.automatic)

            GroupBox("Custom style") {
                Text("An underlined heading, no border.")
            }
                .groupBoxStyle(HeadingGroupBoxStyle())
        }
    }
}

/// A custom ``GroupBoxStyle``: an underlined heading with the content indented
/// beneath it — no border chrome.
private struct HeadingGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: GroupBoxStyleConfiguration) -> some View {
        if let label = configuration.label {
            label.bold().underline()
        }
        configuration.content.padding(.leading, 2)
    }
}
