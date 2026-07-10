//
//  Toggle.swift
//  sclt
//
//  Created by Keisuke Chinone on 2026/07/07.
//

import Foundation
import ArgumentParser
import SwiftLI

/// A full-screen sample for ``Toggle`` showing its built-in styles. Tab moves
/// focus; Space / arrows / y-n flip the focused toggle; Ctrl-C quits.
struct ToggleCommand: AsyncParsableCommand, FullScreenCommand {
    static let configuration = CommandConfiguration(
        commandName: "toggle",
        abstract: "Display of Toggle structure",
        discussion: """
        Focusable Yes/No toggles in several styles. Tab / Shift-Tab move focus,
        Space flips, arrows pick a side, y/n set it, Ctrl-C quits.
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    @State var proceed = true
    @State var verbose = false
    @State var overwrite = false

    mutating func run() async throws {
        startBodyRendering()
        await waitUntilInterrupted()
        stopBodyRendering()
        print("proceed=\(proceed) verbose=\(verbose) overwrite=\(overwrite)")
    }

    var body: some View {
        Text(" Toggle ")
            .bold()
            .forgroundColor(.black)
            .background(.cyan)

        Spacer()

        Text("Tab: focus   Space: flip   ←/→ or y/n: set   Ctrl-C: quit")
            .forgroundColor(.eight_bit(240))

        Spacer()

        HStack(spacing: 1) {
            Text("Yes/No   :")
            Toggle("Proceed?", isOn: $proceed)
        }
        HStack(spacing: 1) {
            Text("Checkbox :")
            Toggle("Verbose logging", isOn: $verbose)
                .toggleStyle(CheckboxToggleStyle())
        }
        HStack(spacing: 1) {
            Text("Switch   :")
            Toggle("Overwrite", isOn: $overwrite)
                .toggleStyle(SwitchToggleStyle())
        }
        HStack(spacing: 1) {
            Text("Prompt   :")
            Toggle("Continue?", isOn: $proceed)
                .toggleStyle(PromptToggleStyle())
        }

        Spacer()
        Divider()
        Text("proceed=\(proceed)  verbose=\(verbose)  overwrite=\(overwrite)")
            .forgroundColor(.yellow)
    }
}
