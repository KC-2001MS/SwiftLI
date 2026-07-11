//
//  SwiftLogo.swift
//  SwiftLI
//  
//  Created by Keisuke Chinone on 2024/07/23.
//

import ArgumentParser
import SwiftLI

/// A static display of ``SwiftLogo``, rendered inline so the output stays in
/// the terminal scrollback.
struct SwiftLogoCommand: InlineCommand {
    static let configuration = CommandConfiguration(
        commandName: "swiftlogo",
        abstract: "Display of SwiftLogo structure",
        discussion: """
        Command to check the display of SwiftLogo structure
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
                .navigationTitle("SwiftLogo")

            SwiftLogo()

            Text("* This library was created by Swift.")
                .fontWeight(.thin)
                .padding(.top, 1)
        }
    }
}
