//
//  Navigation.swift
//  sclt
//
//  Created by Keisuke Chinone on 2026/07/11.
//

import Foundation
import ArgumentParser
import SwiftLI

/// A full-screen sample of ``NavigationSplitView``: sidebar links replace the
/// detail column, and each destination sets the title bar.
struct NavigationCommand: FullScreenCommand {
    static let configuration = CommandConfiguration(
        commandName: "navigation",
        abstract: "Display of NavigationSplitView and NavigationLink",
        discussion: """
        A sidebar of NavigationLinks next to a detail column. Activating a link
        (Return / Space) replaces the detail; navigationTitle / navigationSubtitle
        fill the title bar above. Tab / Shift-Tab move focus, Ctrl-C quits.
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    // No run() — FullScreenCommand's default runs the session until Ctrl-C.

    var body: some Scene {
        NavigationSplitView {
            List {
                NavigationLink("General") {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Language: English")
                        Text("Time zone: UTC+9")
                    }
                        .navigationTitle("General")
                }
                NavigationLink("Network") {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Status: Connected")
                        Text("Latency: 24 ms")
                    }
                        .navigationTitle("Network")
                }
            }
        } detail: {
            Text("Select a section with Return or Space.")
                .forgroundColor(.eight_bit(240))
                .navigationTitle("Navigation")
                .navigationSubtitle("sclt sample")
        }
    }
}
