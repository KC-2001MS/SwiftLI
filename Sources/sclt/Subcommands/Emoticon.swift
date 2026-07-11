//
//  Emoticon.swift
//
//
//  Created by Keisuke Chinone on 2024/05/27.
//

import ArgumentParser
import SwiftLI

/// A static catalogue of ``Emoticon``, rendered inline so the output stays in
/// the terminal scrollback.
struct EmoticonCommand: InlineCommand {
    static let configuration = CommandConfiguration(
        commandName: "emoticon",
        abstract: "Display of Emoticon structure",
        discussion: """
        Command to check the display of Emoticon structure
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    // No run() — the default inline session renders once and, with nothing
    // left to do, exits by itself.

    var body: some Scene {
        NavigationStack {
            Text("init()")
                .forgroundColor(Color.cyan)
                .navigationTitle("Emoticon")

            HStack(spacing: 1) {
                Emoticon()
                Spacer()
                Text("Emoticon()  ← default :)")
                    .fontWeight(.thin)
                    .forgroundColor(.red)
            }

            Text("EyesStyle cases")
                .forgroundColor(Color.cyan)
                .padding(.top, 1)

            ForEach(EyesStyle.allCases) { eye in
                HStack(spacing: 1) {
                    Emoticon(eye: eye, mouth: .default)
                    Spacer()
                    Text(".\(eye)")
                        .fontWeight(.thin)
                        .forgroundColor(.red)
                }
            }

            Text("MouthStyle cases")
                .forgroundColor(Color.cyan)
                .padding(.top, 1)

            ForEach(MouthStyle.allCases) { mouth in
                HStack(spacing: 1) {
                    Emoticon(eye: .default, mouth: mouth)
                    Spacer()
                    Text(".\(mouth)")
                        .fontWeight(.thin)
                        .forgroundColor(.red)
                }
            }
        }
    }
}
