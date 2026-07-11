//
//  Label.swift
//  SwiftLI
//  
//  Created by Keisuke Chinone on 2024/07/23.
//

import ArgumentParser
import SwiftLI

/// A static catalogue of ``Label`` and its styles, rendered inline so the
/// output stays in the terminal scrollback.
struct LabelCommand: InlineCommand {
    static let configuration = CommandConfiguration(
        commandName: "label",
        abstract: "Display of Label structure",
        discussion: """
        Command to check the display of Label structure
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    // No run() — the default inline session renders once and, with nothing
    // left to do, exits by itself.

    var body: some Scene {
        NavigationStack {
            HStack(spacing: 1) {
                Label(
                    "init(_ title: String, unicodeImage: Int)",
                    unicodeImage: 0x2705
                )
                .forgroundColor(.cyan)
                Spacer()
                Text("0x2705 ✅")
                    .fontWeight(.thin)
                    .forgroundColor(.green)
            }
            .navigationTitle("Label")

            HStack(spacing: 1) {
                Label(image: "★", title: "init(image: String, title: String)")
                    .forgroundColor(.cyan)
                Spacer()
                Text("★")
                    .fontWeight(.thin)
                    .forgroundColor(.yellow)
            }

            HStack(spacing: 1) {
                Label("labelStyle(.iconOnly)", unicodeImage: 0x1F4BE)
                    .labelStyle(.iconOnly)
                Spacer()
                Text("icon only")
                    .fontWeight(.thin)
                    .forgroundColor(.red)
            }

            HStack(spacing: 1) {
                Label("labelStyle(.titleOnly)", unicodeImage: 0x1F4BE)
                    .labelStyle(.titleOnly)
                Spacer()
                Text("title only")
                    .fontWeight(.thin)
                    .forgroundColor(.red)
            }
        }
    }
}
