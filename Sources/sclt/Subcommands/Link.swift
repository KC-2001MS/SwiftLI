//
//  Link.swift
//  sclt
//
//  Created by Keisuke Chinone on 2026/07/12.
//

import Foundation
import ArgumentParser
import SwiftLI

/// A full-screen sample of ``Link``: OSC 8 hyperlinks that join the focus
/// ring, so Return / Space open the destination.
struct LinkCommand: FullScreenCommand {
    static let configuration = CommandConfiguration(
        commandName: "link",
        abstract: "Display of Link structure",
        discussion: """
        Clickable OSC 8 hyperlinks. On supporting terminals (iTerm2, kitty,
        WezTerm, Ghostty, …) the label is clickable; everywhere a link joins
        the focus ring, so Tab reaches it and Return / Space open the
        destination. Ctrl-C quits.
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    // No run() — FullScreenCommand's default runs the session until Ctrl-C.

    var body: some Scene {
        NavigationStack {
            HStack(spacing: 1) {
                Text("Link(_ label:, destination:)")
                    .forgroundColor(.cyan)
                Link("SwiftLI on GitHub", destination: "https://github.com/KC-2001MS/SwiftLI")
            }
                .navigationTitle("Link")
                .navigationSubtitle("Tab: focus   Return/Space: open   Ctrl-C: quit")

            // A link accepts the common style modifiers, so it can look like
            // a classic underlined blue hyperlink.
            HStack(spacing: 1) {
                Text("Styled like a web link:")
                    .forgroundColor(.cyan)
                Link("Apple", destination: "https://apple.com")
                    .forgroundColor(.blue)
                    .underline()
            }
                .padding(.top, 1)

            Text("Terminal.app ignores OSC 8 — the plain label still renders.")
                .forgroundColor(.eight_bit(240))
                .padding(.top, 1)
        }
    }
}
