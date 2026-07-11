//
//  TextEditor.swift
//  sclt
//
//  Created by Keisuke Chinone on 2026/07/07.
//

import Foundation
import ArgumentParser
import SwiftLI

/// A full-screen sample for ``TextEditor``: a multi-line note area where Return
/// inserts a newline and the arrows move between lines. Ctrl-C quits.
struct TextEditorCommand: FullScreenCommand {
    static let configuration = CommandConfiguration(
        commandName: "texteditor",
        abstract: "Display of TextEditor structure",
        discussion: """
        A multi-line editor: type freely, Return inserts a newline, arrows move
        between lines (Ctrl-A/E line start/end, Ctrl-K/U/W kills). Tab or Esc
        leaves the editor (Textual TextArea style); Ctrl-C quits.
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    @State var notes = ""

    // No run() — FullScreenCommand's default runs the session until Ctrl-C.

    var body: some Scene {
        NavigationStack {
            let lineCount = notes.isEmpty ? 0 : notes.components(separatedBy: "\n").count
            TextEditor("Type your notes here...", text: $notes, height: 8)
                .navigationTitle("TextEditor")
                .navigationSubtitle("Return: newline   Tab: leave   Arrows: move   Esc: leave   Ctrl-C: quit")

            Divider()
                .padding(.top, 1)
            Text("\(notes.count) chars, \(lineCount) line(s)")
                .forgroundColor(.yellow)
        }
    }
}
