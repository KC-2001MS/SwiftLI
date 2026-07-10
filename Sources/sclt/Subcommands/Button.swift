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
struct ButtonCommand: AsyncParsableCommand, FullScreenCommand {
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

    mutating func run() async throws {
        startBodyRendering()
        await waitUntilInterrupted()
        stopBodyRendering()
        print("count=\(count) last=\(lastPressed)")
    }

    var body: some View {
        Text(" Button ")
            .bold()
            .forgroundColor(.black)
            .background(.cyan)

        Spacer()

        Text("Tab: focus   Return/Space: press   Ctrl-C: quit")
            .forgroundColor(.eight_bit(240))

        Spacer()

        Text("Default style:").forgroundColor(.cyan)
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

        Spacer()

        Text("Bordered / plain / custom label:").forgroundColor(.cyan)
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

        Spacer()
        Divider()
        Text("count: \(count)   last pressed: \(lastPressed)")
            .forgroundColor(.yellow)
    }
}
