//
//  Frame.swift
//  sclt
//
//  Created by Keisuke Chinone on 2026/07/07.
//

import Foundation
import ArgumentParser
import SwiftLI

/// A full-screen sample for ``View/frame(width:height:alignment:)`` and text
/// wrapping: the same paragraph shown at several widths, with and without a
/// line limit, plus a fixed, aligned box.
struct FrameCommand: AsyncParsableCommand, FullScreenViewableCommand {
    static let configuration = CommandConfiguration(
        commandName: "frame",
        abstract: "Display of frame sizing and text wrapping",
        discussion: """
        Shows how a width-constrained frame wraps Text onto multiple lines, how
        lineLimit truncates with an ellipsis, and how alignment positions a
        smaller child inside a fixed box. Ctrl-C quits.
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    private var paragraph: String { "SwiftLI lays out declarative views for the terminal, wrapping long text to the available width just like SwiftUI." }

    mutating func run() async throws {
        startBodyRendering()
        await waitUntilInterrupted()
        stopBodyRendering()
    }

    var body: some View {
        Group {
            Text(" frame & wrapping ")
                .bold()
                .forgroundColor(.black)
                .background(.cyan)

            Spacer()

            Text("Wrapped to width 30:").forgroundColor(.cyan)
            Text(paragraph)
                .frame(width: 30, alignment: .topLeading)

            Spacer()

            Text("Width 30, lineLimit 2:").forgroundColor(.cyan)
            Text(paragraph)
                .frame(width: 30, alignment: .topLeading)
                .lineLimit(2)

            Spacer()

            Text("Fixed 20×3 box, centered:").forgroundColor(.cyan)
            Text("centered")
                .background(.eight_bit(238))
                .frame(width: 20, height: 3, alignment: .center)

            Spacer()
            Divider()
            Text("Ctrl-C to quit").forgroundColor(.eight_bit(240))
        }
    }
}
