//
//  ViewThatFits.swift
//  sclt
//
//  Created by Keisuke Chinone on 2026/07/12.
//

import ArgumentParser
import SwiftLI

/// A static catalogue of ``ViewThatFits``: the same candidate list constrained
/// to three widths, so each width picks a different candidate.
struct ViewThatFitsCommand: InlineCommand {
    static let configuration = CommandConfiguration(
        commandName: "viewthatfits",
        abstract: "Display of ViewThatFits structure",
        discussion: """
        Command to check the display of the ViewThatFits structure: the first
        candidate that fits the proposed width is shown, so the same view picks
        a longer or shorter form depending on the space it is given
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    // No run() — the default inline session renders once and, with nothing
    // left to do, exits by itself.

    /// The candidate list, widest first — every sample below reuses it.
    private func progressLabel() -> ViewThatFits {
        ViewThatFits {
            Text("Full download progress: 42% complete")
            Text("42% complete")
            Text("42%")
        }
    }

    var body: some Scene {
        NavigationStack {
            Text("The same ViewThatFits at three widths:")
                .forgroundColor(.cyan)
                .navigationTitle("ViewThatFits")

            // Wide enough for the first candidate.
            progressLabel()
                .frame(width: 42, alignment: .topLeading)
                .border(.rounded, color: .eight_bit(240))

            // Only the middle candidate fits.
            progressLabel()
                .frame(width: 16, alignment: .topLeading)
                .border(.rounded, color: .eight_bit(240))

            // Only the shortest candidate fits.
            progressLabel()
                .frame(width: 6, alignment: .topLeading)
                .border(.rounded, color: .eight_bit(240))

            Text("Candidates are listed widest first; the last is the fallback.")
                .forgroundColor(.eight_bit(240))
                .padding(.top, 1)
        }
    }
}
