//
//  Label.swift
//  SwiftLI
//  
//  Created by Keisuke Chinone on 2024/07/23.
//

import ArgumentParser
import SwiftLI

struct LabelCommand: AsyncParsableCommand, FullScreenCommand {
    static let configuration = CommandConfiguration(
        commandName: "label",
        abstract: "Display of Label structure",
        discussion: """
        Command to check the display of Label structure
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    @State var isActive: Bool = false

    mutating func run() async throws {
        startBodyRendering()
        for _ in 0..<3 {
            try await Task.sleep(nanoseconds: 800_000_000)
            isActive.toggle()
        }
        stopBodyRendering()
    }

    var body: some View {
        Text("Label View")
            .background(Color.white)
            .forgroundColor(Color.blue)
            .bold()

        HStack(spacing: 1) {
            Label(
                "init(_ title: String, unicodeImage: Int)",
                unicodeImage: isActive ? 0x2705 : 0x274C
            )
            .forgroundColor(isActive ? .green : .cyan)
            Spacer(1)
            Text(isActive ? "0x2705 ✅" : "0x274C ❌")
                .fontWeight(.thin)
                .forgroundColor(isActive ? .green : .red)
        }
    }
}
