//
//  Menu.swift
//  sclt
//
//  Created by Keisuke Chinone on 2026/07/10.
//

import Foundation
import ArgumentParser
import SwiftLI

/// A full-screen sample composing ``Menu`` and an activatable ``Link`` out of
/// ``Button``s. Tab moves focus; Return / Space activate.
struct MenuCommand: FullScreenCommand {
    static let configuration = CommandConfiguration(
        commandName: "menu",
        abstract: "Display of Menu and activatable Link",
        discussion: """
        Button-composed views: a Menu of actions and a Link that joins the focus
        ring. Tab / Shift-Tab move focus, Return or Space activate, Ctrl-C quits.
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    @State var lastAction = "none"
    @State var deleted = false

    // No run() — FullScreenCommand's default runs the session until Ctrl-C.

    var body: some Scene {
        NavigationStack {
            Menu("File") {
                Button("New") { lastAction = "New" }
                Button("Open…") { lastAction = "Open" }
                Button("Delete", role: .destructive) {
                    lastAction = "Deleted"
                    deleted = true
                }
            }
                .navigationTitle("Menu")
                .navigationSubtitle("Tab: focus   Return/Space: activate   Ctrl-C: quit")

            HStack(spacing: 1) {
                Text("Docs:")
                Link("SwiftLI on GitHub", destination: "https://github.com/KC-2001MS/SwiftLI")
            }
                .padding(.top, 1)

            Divider()
                .padding(.top, 1)
            Text("last action: \(lastAction)   deleted: \(deleted ? "yes" : "no")")
                .forgroundColor(.yellow)
        }
    }
}
