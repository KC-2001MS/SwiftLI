//
//  Group.swift
//
//  
//  Created by Keisuke Chinone on 2024/05/28.
//

import ArgumentParser
import SwiftLI

/// A static display of ``Group``, rendered inline so the output stays in the
/// terminal scrollback.
struct GroupCommand: InlineCommand {
    static let configuration = CommandConfiguration(
        commandName: "group",
        abstract: "Display of Group structure",
        discussion: """
        Command to check the display of Group structure
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    // No run() — the default inline session renders once and, with nothing
    // left to do, exits by itself.

    var body: some Scene {
        NavigationStack {
            Text("Group(@ViewBuilder contents: () -> [View])")
                .forgroundColor(.cyan)
                .navigationTitle("Group")

            Group {
                Text("Group")
            }
        }
    }
}
