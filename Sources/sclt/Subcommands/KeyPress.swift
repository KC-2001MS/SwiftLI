//
//  KeyPress.swift
//  sclt
//
//  Created by Keisuke Chinone on 2026/11/07.
//

import Foundation
import ArgumentParser
import SwiftLI

/// A full-screen sample for ``View/onKeyPress(action:)``: keys the focused
/// control leaves alone — letters and Control chords here — are logged by a
/// screen-wide handler. Return activates the focused link, and
/// the pushed page pops itself on Escape via `@Environment(\.dismiss)`;
/// q quits.
struct KeyPressCommand: FullScreenCommand {
    static let configuration = CommandConfiguration(
        commandName: "keypress",
        abstract: "Display of onKeyPress modifier",
        discussion: """
        A screen-wide key handler: letters and Ctrl chords are logged no
        matter what has focus, Return opens the focused link's detail page
        (Escape pops it back), q quits.
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    @State var log: [String] = []
    @Environment(\.dismiss) var dismiss

    // No run() — FullScreenCommand's default runs the session until dismissed.

    var body: some Scene {
        NavigationStack {
            Text("Type letters or Ctrl chords — they are logged below.")
                .navigationTitle("onKeyPress")
                .navigationSubtitle("letters/Ctrl: log   Return: detail   q: quit")
            NavigationLink("Open detail") { KeyPressDetailView() }
            Divider()
            Text(log.suffix(8).joined(separator: "\n"))
                .foregroundStyle(.yellow)
        }
        .onKeyPress("q") {
            dismiss()
            return .handled
        }
        .onKeyPress { press in
            if press.modifiers.contains(.control) {
                log.append("control-\(press.key.character)")
                return .handled
            }
            // Only printable keys are logged; arrows and the like use
            // private-use characters, as in SwiftUI's KeyEquivalent.
            let printable = press.characters.unicodeScalars.allSatisfy {
                let category = $0.properties.generalCategory
                return category != .control && category != .privateUse
            }
            guard printable else { return .ignored }
            log.append("character \(press.characters)")
            return .handled
        }
    }
}

/// The pushed page: Escape pops it through `@Environment(\.dismiss)`.
struct KeyPressDetailView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Text("Detail page — Escape goes back.")
            .navigationTitle("Detail")
            .onKeyPress(.escape) {
                dismiss()
                return .handled
            }
    }
}
