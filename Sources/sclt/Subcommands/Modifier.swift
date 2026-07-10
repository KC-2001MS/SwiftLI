//
//  Modifier.swift
//  sclt
//
//  Created by Keisuke Chinone on 2026/07/10.
//

import Foundation
import ArgumentParser
import SwiftLI

/// A full-screen catalogue of every View-independent modifier, shown one by
/// one: the style modifiers (colours, weights, decorations) as one row each,
/// followed by the layout modifiers (padding, frame, lineLimit, border,
/// shadow) as small blocks.
struct ModifierCommand: AsyncParsableCommand, FullScreenCommand {
    static let configuration = CommandConfiguration(
        commandName: "modifier",
        abstract: "Display of the View-independent modifiers, one by one",
        discussion: """
        Every modifier that applies to any View, each with its call site next to
        its effect: the style modifiers (forgroundColor, background, bold,
        fontWeight, italic, underline, strikethrough, blink, hidden) and the
        layout modifiers (padding, frame, lineLimit, border, shadow).
        Ctrl-C quits.
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    /// The column width reserved for each modifier's call site, so the samples
    /// line up.
    private let callWidth = 34

    private var paragraph: String { "SwiftLI wraps long text to the available width just like SwiftUI." }

    mutating func run() async throws {
        startBodyRendering()
        await waitUntilInterrupted()
        stopBodyRendering()
    }

    /// One catalogue row: the call site in a fixed-width column, then the
    /// sample it produces.
    private func row(_ call: String, _ sample: some View) -> some View {
        HStack(spacing: 1) {
            Text(call).forgroundColor(.eight_bit(245)).frame(width: callWidth, alignment: .topLeading)
            sample
        }
    }

    var body: some View {
        Text(" modifier ")
            .bold()
            .forgroundColor(.black)
            .background(.cyan)

        Spacer()

        Text("Style modifiers:").forgroundColor(.cyan)
        row(".forgroundColor(.red)", Text("Sample").forgroundColor(.red))
        row(".background(.yellow)", Text("Sample").background(.yellow).forgroundColor(.black))
        row(".bold()", Text("Sample").bold())
        row(".fontWeight(.thin)", Text("Sample").fontWeight(.thin))
        row(".italic()", Text("Sample").italic())
        row(".underline()", Text("Sample").underline())
        row(".strikethrough()", Text("Sample").strikethrough())
        row(".blink(.default)", Text("Sample").blink(.default))
        row(".hidden()", HStack(spacing: 0) {
            Text("[").forgroundColor(.eight_bit(240))
            Text("Sample").hidden()
            Text("] (blanked, keeps its width)").forgroundColor(.eight_bit(240))
        })

        Spacer()

        Text("Layout modifiers:").forgroundColor(.cyan)
        row(".padding()", Text("Sample").padding().background(.eight_bit(238)))
        row(".frame(width: 14, height: 3, ...)", Text("Sample").frame(width: 14, height: 3, alignment: .center).background(.eight_bit(238)))
        row(".frame(width: 22) + wrapping", Text(paragraph).frame(width: 22, alignment: .topLeading))
        row(".lineLimit(2)", Text(paragraph).frame(width: 22, alignment: .topLeading).lineLimit(2))
        row(".border(.rounded, color: .green)", Text("Sample").padding(.horizontal, 1).border(.rounded, color: .green))
        row(".border(fill:) + .shadow()", Text("Sample").padding(.horizontal, 1).border(.rounded, color: .white, fill: .eight_bit(24)).shadow())

        Spacer()
        Divider()
        Text("Ctrl-C to quit").forgroundColor(.eight_bit(240))
    }
}
