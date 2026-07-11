//
//  Divider.swift
//
//  
//  Created by Keisuke Chinone on 2024/05/29.
//

import ArgumentParser
import SwiftLI

/// A static catalogue of ``Divider``, rendered inline so the output stays in
/// the terminal scrollback.
struct DividerCommand: InlineCommand {
    static let configuration = CommandConfiguration(
        commandName: "divider",
        abstract: "Display of Divider structure",
        discussion: """
        Command to check the display of Divider structure
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    // No run() — the default inline session renders once and, with nothing
    // left to do, exits by itself.

    var body: some Scene {
        NavigationStack {
            // Full-width divider: no count → spans the whole terminal width.
            Text("Divider() full width:")
                .forgroundColor(.cyan)
                .navigationTitle("Divider")
            Divider()

            // Horizontal divider (VStack context)
                .padding(.top, 1)
            Text("Divider(_ count: Int) in VStack (horizontal):")
                .forgroundColor(.cyan)
            VStack {
                Text("Section A").forgroundColor(.green)
                Divider(20)
                Text("Section B").forgroundColor(.yellow)
            }

            // Vertical divider (HStack context)
                .padding(.top, 1)
            Text("Divider() in HStack (vertical):")
                .forgroundColor(.cyan)
            HStack(spacing: 1) {
                Text("Left").forgroundColor(.red)
                Divider()
                Text("Right").forgroundColor(.blue)
            }

            // lineStyle demo
                .padding(.top, 1)
            Text("Divider().lineStyle(.double_line):")
                .forgroundColor(.cyan)
            VStack {
                Text("Above").forgroundColor(.magenta)
                Divider(20).lineStyle(.double_line)
                Text("Below").forgroundColor(.cyan)
            }
        }
    }
}
