//
//  Picker.swift
//  sclt
//
//  Created by Keisuke Chinone on 2026/07/07.
//

import Foundation
import ArgumentParser
import SwiftLI

/// A full-screen sample for ``Picker`` showing its built-in styles. Tab moves
/// focus; arrows / Space / digits change the selection; Ctrl-C quits.
struct PickerCommand: FullScreenCommand {
    static let configuration = CommandConfiguration(
        commandName: "picker",
        abstract: "Display of Picker structure",
        discussion: """
        Option selectors in several styles. Tab / Shift-Tab move focus, arrows
        or Space change the selection, digits 1-9 jump, Ctrl-C quits.
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    @State var color = 0
    @State var size = 1
    @State var fruit = 2

    private var colors: [String] { ["Red", "Green", "Blue"] }
    private var sizes: [String] { ["S", "M", "L", "XL"] }
    private var fruits: [String] { ["Apple", "Banana", "Cherry", "Date"] }

    // No run() — FullScreenCommand's default runs the session until Ctrl-C.

    var body: some Scene {
        NavigationStack {
            HStack(spacing: 1) {
                Text("Inline    :")
                Picker("Color", selection: $color, options: colors)
            }
                .navigationTitle("Picker")
                .navigationSubtitle("Tab: focus   ←/→ or Space: change   1-9: jump   Ctrl-C: quit")
            HStack(spacing: 1) {
                Text("Segmented :")
                Picker("Size", selection: $size, options: sizes)
                    .pickerStyle(SegmentedPickerStyle())
            }

            Text("List:").forgroundColor(.cyan)
                .padding(.top, 1)
            Picker("Fruit", selection: $fruit, options: fruits)
                .pickerStyle(ListPickerStyle())

            Divider()
                .padding(.top, 1)
            Text("color=\(colors[color])  size=\(sizes[size])  fruit=\(fruits[fruit])")
                .forgroundColor(.yellow)
        }
    }
}
