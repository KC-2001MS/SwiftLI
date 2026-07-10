//
//  List.swift
//  sclt
//
//  Created by Keisuke Chinone on 2026/07/07.
//

import Foundation
import ArgumentParser
import SwiftLI

/// A full-screen sample for ``List``: a selectable, scrolling list of items.
/// Arrow keys move the selection, the list scrolls to follow, Ctrl-C quits.
struct ListCommand: AsyncParsableCommand, FullScreenCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "Display of List structure",
        discussion: """
        A selectable list bound to a selection: ↑/↓ move the highlight,
        Home/End jump to the ends, and the list scrolls to keep the selection in
        view. Ctrl-C quits.
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    @State private var selection: Int? = 0

    private var items: [String] { (1...40).map { "Item \($0)" } }

    mutating func run() async throws {
        startBodyRendering()
        await waitUntilInterrupted()
        stopBodyRendering()
    }

    var body: some View {
        Text(" List ")
            .bold()
            .forgroundColor(.black)
            .background(.cyan)

        Spacer()

        Text("↑/↓: select   Home/End: jump   Ctrl-C: quit")
            .forgroundColor(.eight_bit(240))

        Spacer()

        List(items, selection: $selection, height: 10) { item in
            Text(item)
        }

        Spacer()
        Divider()
        Text("Selected: \(selection.map { items[$0] } ?? "none")")
            .forgroundColor(.yellow)
    }
}
