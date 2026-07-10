//
//  ScrollView.swift
//  sclt
//
//  Created by Keisuke Chinone on 2026/07/07.
//

import Foundation
import ArgumentParser
import SwiftLI

/// A full-screen sample for ``ScrollView``: a tall list shown through a short
/// viewport. Arrow keys scroll, Space pages, Home/End jump, Ctrl-C quits.
struct ScrollViewCommand: AsyncParsableCommand, FullScreenCommand {
    static let configuration = CommandConfiguration(
        commandName: "scrollview",
        abstract: "Display of ScrollView structure",
        discussion: """
        A fixed-height viewport over a 50-row list. ↑/↓ scroll one line, Space
        pages down, Home/End jump to the ends; a proportional scrollbar sits to
        the right. Ctrl-C quits.
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    mutating func run() async throws {
        startBodyRendering()
        await waitUntilInterrupted()
        stopBodyRendering()
    }

    var body: some View {
        Text(" ScrollView ")
            .bold()
            .forgroundColor(.black)
            .background(.cyan)

        Spacer()

        Text("↑/↓: scroll   Space: page   Home/End: jump   Ctrl-C: quit")
            .forgroundColor(.eight_bit(240))

        Spacer()

        ScrollView(height: 12) {
            ForEach(0..<50) { i in
                HStack(spacing: 1) {
                    Text(String(format: "%3d", i)).forgroundColor(.eight_bit(240))
                    Text("│").forgroundColor(.cyan)
                    Text("List item number \(i)")
                }
            }
        }

        Spacer()
        Divider()
        Text("A 12-row window onto 50 rows of content")
            .forgroundColor(.yellow)
    }
}
