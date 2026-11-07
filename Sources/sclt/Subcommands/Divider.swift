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
                .foregroundStyle(.cyan)
                .navigationTitle("Divider")
            Divider()

            // Horizontal divider (VStack context)
                .padding(.top, 1)
            Text("Divider().frame(width: 20) in VStack (horizontal):")
                .foregroundStyle(.cyan)
            VStack {
                Text("Section A").foregroundStyle(.green)
                Divider().frame(width: 20)
                Text("Section B").foregroundStyle(.yellow)
            }

            // Vertical divider (HStack context)
                .padding(.top, 1)
            Text("Divider() in HStack (vertical):")
                .foregroundStyle(.cyan)
            HStack(spacing: 1) {
                Text("Left").foregroundStyle(.red)
                Divider()
                Text("Right").foregroundStyle(.blue)
            }

            // lineStyle demo
                .padding(.top, 1)
            Text("Divider().lineStyle(.doubleLine):")
                .foregroundStyle(.cyan)
            VStack {
                Text("Above").foregroundStyle(.magenta)
                Divider().lineStyle(.doubleLine).frame(width: 20)
                Text("Below").foregroundStyle(.cyan)
            }
        }
    }
}
