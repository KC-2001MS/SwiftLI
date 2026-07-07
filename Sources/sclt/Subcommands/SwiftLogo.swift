//
//  SwiftLogo.swift
//  SwiftLI
//  
//  Created by Keisuke Chinone on 2024/07/23.
//

import ArgumentParser
import SwiftLI

struct SwiftLogoCommand: AsyncParsableCommand, InlineViewableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swift",
        abstract: "Display of SwiftLogo structure",
        discussion: """
        Command to check the display of SwiftLogo structure
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    @State var isActive: Bool = false

    mutating func run() async throws {
        // The logo is static, so draw it inline once and leave it in the
        // scrollback — no alternate screen, no need to keep the process alive.
        startBodyRendering()
        stopBodyRendering()
    }

    var body: some View {
        Group {
            Text("SwiftLogo View")
                .background(Color.white)
                .forgroundColor(Color.blue)
                .bold()

            Text("init()")
                .forgroundColor(Color.cyan)

            SwiftLogo()

            Spacer()

            Text("* This library was created by Swift.")
                .fontWeight(.thin)
        }
    }
}
