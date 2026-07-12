//
//  AnyView.swift
//  sclt
//
//  Created by Keisuke Chinone on 2026/07/12.
//

import ArgumentParser
import SwiftLI

/// A static catalogue of ``AnyView``, rendered inline so the output stays in
/// the terminal scrollback.
struct AnyViewCommand: InlineCommand {
    static let configuration = CommandConfiguration(
        commandName: "anyview",
        abstract: "Display of AnyView structure",
        discussion: """
        Command to check the display of the AnyView structure: type erasure
        that lets heterogeneous view types share one static type
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    /// Heterogeneous views (a Text, a Label, a Gauge) sharing one array type.
    private var mixed: [AnyView] {
        [
            AnyView(Text("Text").bold()),
            AnyView(Label("Label", unicodeImage: 0x2B50)),
            AnyView(Gauge(value: 0.4).frame(width: 12, alignment: .topLeading)),
        ]
    }

    // No run() — the default inline session renders once and, with nothing
    // left to do, exits by itself.

    var body: some Scene {
        NavigationStack {
            Text("AnyView(_ view: some View)")
                .forgroundColor(.cyan)
                .navigationTitle("AnyView")

            Text("A [AnyView] array holding a Text, a Label and a Gauge:")
                .forgroundColor(.eight_bit(245))

            ForEach(mixed) { view in
                view
            }

            // Both branches erase to the same type, so a function can return
            // either — the classic AnyView use case.
            Text("Erasing branches of different types:")
                .forgroundColor(.eight_bit(245))
                .padding(.top, 1)

            HStack(spacing: 1) {
                badge(ok: true)
                badge(ok: false)
            }
        }
    }

    private func badge(ok: Bool) -> AnyView {
        if ok {
            AnyView(Text("PASS").forgroundColor(.green).bold())
        } else {
            AnyView(Text("FAIL").forgroundColor(.red).bold())
        }
    }
}
