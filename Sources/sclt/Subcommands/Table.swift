//
//  Table.swift
//  sclt
//
//  Created by Keisuke Chinone on 2026/07/07.
//

import Foundation
import ArgumentParser
import SwiftLI

/// A full-screen sample for ``Table``: a people grid that fills the terminal
/// width, with a fixed-width column and truncating cells.
struct TableCommand: FullScreenCommand {
    static let configuration = CommandConfiguration(
        commandName: "table",
        abstract: "Display of Table structure",
        discussion: """
        A data-driven table that takes the full terminal width: flexible columns
        share the leftover space and long cells truncate with an ellipsis.
        Ctrl-C quits.
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    private struct Person {
        let name: String
        let role: String
        let email: String
    }

    @State private var selection: Int? = 0

    private var people: [Person] {
        let roles = ["Engineer", "Researcher", "Designer", "Admiral", "Manager"]
        return (1...40).map { i in
            Person(name: "Person \(i)", role: roles[i % roles.count], email: "person\(i)@example.com")
        }
    }

    // No run() — FullScreenCommand's default runs the session until Ctrl-C.

    var body: some Scene {
        NavigationStack {
            Table(people, selection: $selection, height: 10) {
                TableColumn("Name") { $0.name }
                TableColumn("Role", width: 12) { $0.role }
                TableColumn("Email") { $0.email }
            }
                .navigationTitle("Table")
                .navigationSubtitle("↑/↓: select   Home/End: jump   header stays pinned   Ctrl-C: quit")

            Divider()
                .padding(.top, 1)
            Text("Fills the terminal width; body scrolls under a pinned header.")
                .forgroundColor(.yellow)
        }
    }
}
