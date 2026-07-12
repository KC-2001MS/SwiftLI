//
//  Grid.swift
//  sclt
//
//  Created by Keisuke Chinone on 2026/07/12.
//

import ArgumentParser
import SwiftLI

/// A static catalogue of ``VGrid`` and ``HGrid``, rendered inline so the
/// output stays in the terminal scrollback.
struct GridCommand: InlineCommand {
    static let configuration = CommandConfiguration(
        commandName: "grid",
        abstract: "Display of VGrid and HGrid structures",
        discussion: """
        Command to check the display of the VGrid (fixed column count, wraps
        into rows) and HGrid (fixed row count, wraps into columns) structures
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    private var fruits: [String] {
        ["Apple", "Banana", "Cherry", "Kiwi", "Mango", "Peach", "Plum", "Fig"]
    }

    // No run() — the default inline session renders once and, with nothing
    // left to do, exits by itself.

    var body: some Scene {
        NavigationStack {
            // Cells fill left-to-right and wrap every `columns` items; each
            // column is as wide as its widest cell, so the cells line up.
            Text("VGrid(columns: 3, spacing: 2)")
                .forgroundColor(.cyan)
                .navigationTitle("Grid")

            VGrid(columns: 3, spacing: 2) {
                ForEach(fruits) { fruit in
                    Text(fruit)
                }
            }

            // Cells fill top-to-bottom and wrap every `rows` items; each row
            // is as tall as its tallest cell.
            Text("HGrid(rows: 2, spacing: 2)")
                .forgroundColor(.cyan)
                .padding(.top, 1)

            HGrid(rows: 2, spacing: 2) {
                ForEach(fruits) { fruit in
                    Text(fruit)
                }
            }
        }
    }
}
