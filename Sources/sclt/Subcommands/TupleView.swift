//
//  TupleView.swift
//  sclt
//
//  Created by Keisuke Chinone on 2026/07/12.
//

import ArgumentParser
import SwiftLI

/// A static catalogue of ``TupleView``, rendered inline so the output stays
/// in the terminal scrollback.
struct TupleViewCommand: InlineCommand {
    static let configuration = CommandConfiguration(
        commandName: "tupleview",
        abstract: "Display of TupleView structure",
        discussion: """
        Command to check the display of the TupleView structure: the view a
        ViewBuilder produces for multiple statements, holding each child with
        its concrete type
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    // No run() — the default inline session renders once and, with nothing
    // left to do, exits by itself.

    var body: some Scene {
        NavigationStack {
            Text("TupleView((repeat each Content))")
                .forgroundColor(.cyan)
                .navigationTitle("TupleView")

            // Direct construction — normally a ViewBuilder makes this for you
            // whenever a closure contains more than one view statement.
            TupleView((
                Text("First").forgroundColor(.red),
                Text("Second").forgroundColor(.green),
                Text("Third").forgroundColor(.blue)
            ))

            // A TupleView is transparent: inside an HStack its children join
            // the row individually, with the stack's own spacing.
            Text("Flattened into an HStack(spacing: 3):")
                .forgroundColor(.eight_bit(245))
                .padding(.top, 1)

            HStack(spacing: 3) {
                TupleView((Text("A"), Text("B"), Text("C")))
            }
        }
    }
}
