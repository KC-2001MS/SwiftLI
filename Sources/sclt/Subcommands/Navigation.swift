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
        fill the title bar above. The navigation-specific bar modifiers are all
        here too: toolbar (with ToolbarItem / ToolbarItemGroup),
        navigationBarTitleDisplayMode, toolbarBackground, toolbarColorScheme,
        and toolbarRole. Tab / Shift-Tab move focus, Ctrl-C quits.
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    @State var saves = 0

    // No run() — FullScreenCommand's default runs the session until Ctrl-C.

    var body: some Scene {
        NavigationSplitView {
            List {
                NavigationLink("General") {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Language: English")
                        Text("Time zone: UTC+9")
                        Text("(title bar: .navigationBarTitleDisplayMode(.inline))")
                            .forgroundColor(.eight_bit(240))
                    }
                        .navigationTitle("General")
                        .navigationSubtitle("compact bar")
                        // Title and subtitle share one compact row.
                        .navigationBarTitleDisplayMode(.inline)
                }
                NavigationLink("Network") {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Status: Connected")
                        Text("Latency: 24 ms")
                        Text("(title bar: .toolbarBackground + .toolbarColorScheme + .toolbarRole(.editor))")
                            .forgroundColor(.eight_bit(240))
                    }
                        .navigationTitle("Network")
                        // A filled bar with a forced-dark (light text) scheme
                        // and an editor role, which centres the title.
                        .toolbarBackground(.blue, for: .navigationBar)
                        .toolbarColorScheme(.dark, for: .navigationBar)
                        .toolbarRole(.editor)
                }
            }
        } detail: {
            Text("Select a section with Return or Space.")
                .forgroundColor(.eight_bit(240))
                .navigationTitle("Navigation")
                .navigationSubtitle("sclt sample")
                // Toolbar items fill the title bar by segment: a principal
                // item in the centre, primary actions at the trailing edge.
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("principal")
                    }
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button("Save") { saves += 1 }
                    }
                }
            Text("saves: \(saves)")
                .forgroundColor(.yellow)
                .padding(.top, 1)
        }
    }
}
