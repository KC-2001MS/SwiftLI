//
//  Button.swift
//  sclt
//
//  Created by Keisuke Chinone on 2026/07/10.
//

import Foundation
import ArgumentParser
import SwiftLI

/// A full-screen sample for ``Button`` showing its built-in styles. Tab moves
/// focus; Return / Space activate the focused button; Ctrl-C quits.
struct ButtonCommand: FullScreenCommand {
    static let configuration = CommandConfiguration(
        commandName: "button",
        abstract: "Display of Button structure and styles",
        discussion: """
        Focusable buttons in several styles driving a shared counter. Tab /
        Shift-Tab move focus, Return or Space activate, Ctrl-C quits.
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    @State var count = 0
    @State var lastPressed = "none"

    // No run() — FullScreenCommand's default runs the session until Ctrl-C.

    var body: some Scene {
        NavigationStack {
            Text("Default style:").forgroundColor(.cyan)
                .navigationTitle("Button")
                .navigationSubtitle("Tab: focus   Return/Space: press   Ctrl-C: quit")
            HStack(spacing: 2) {
                Button("Increment") {
                    count += 1
                    lastPressed = "Increment"
                }
                Button("Decrement") {
                    count -= 1
                    lastPressed = "Decrement"
                }
            }

            Text("Bordered / plain / custom label:").forgroundColor(.cyan)
                .padding(.top, 1)
            HStack(alignment: .top, spacing: 2) {
                Button("+10", id: "PlusTen") {
                    count += 10
                    lastPressed = "+10"
                }
                .buttonStyle(.bordered)

                Button("Reset") {
                    count = 0
                    lastPressed = "Reset"
                }
                .buttonStyle(.plain)

                Button(id: "Celebrate", action: {
                    count += 100
                    lastPressed = "Celebrate"
                }) {
                    Label("Celebrate", unicodeImage: 0x1F389)
                }
            }

            Divider()
                .padding(.top, 1)
            Text("count: \(count)   last pressed: \(lastPressed)")
                .forgroundColor(.yellow)
        }
    }
}
