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
struct PickerCommand: AsyncParsableCommand, FullScreenViewableCommand {
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

    mutating func run() async throws {
        startBodyRendering()
        await waitUntilInterrupted()
        stopBodyRendering()
        print("color=\(colors[color]) size=\(sizes[size]) fruit=\(fruits[fruit])")
    }

    var body: some View {
        Group {
            Text(" Picker ")
                .bold()
                .forgroundColor(.black)
                .background(.cyan)

            Spacer()

            Text("Tab: focus   ←/→ or Space: change   1-9: jump   Ctrl-C: quit")
                .forgroundColor(.eight_bit(240))

            Spacer()

            HStack(spacing: 1) {
                Text("Inline    :")
                Picker("Color", selection: $color, options: colors)
            }
            HStack(spacing: 1) {
                Text("Segmented :")
                Picker("Size", selection: $size, options: sizes)
                    .pickerStyle(SegmentedPickerStyle())
            }

            Spacer()

            Text("List:").forgroundColor(.cyan)
            Picker("Fruit", selection: $fruit, options: fruits)
                .pickerStyle(ListPickerStyle())

            Spacer()
            Divider()
            Text("color=\(colors[color])  size=\(sizes[size])  fruit=\(fruits[fruit])")
                .forgroundColor(.yellow)
        }
    }
}
