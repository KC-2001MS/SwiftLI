//
//  Emoticon.swift
//
//
//  Created by Keisuke Chinone on 2024/05/27.
//

import ArgumentParser
import SwiftLI

struct EmoticonCommand: AsyncParsableCommand, ViewableCommand {
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

    @State var eyeIndex: Int = 0
    @State var mouthIndex: Int = 0

    var eyes: [EyesStyle] { EyesStyle.allCases }
    var mouths: [MouthStyle] { MouthStyle.allCases }

    mutating func run() async throws {
        startBodyRendering()
        let steps = max(eyes.count, mouths.count)
        for i in 0..<steps {
            try await Task.sleep(nanoseconds: 400_000_000)
            eyeIndex = i % eyes.count
            mouthIndex = i % mouths.count
        }
        stopBodyRendering()
    }

    var body: some View {
        Group {
            Text("Emoticon View")
                .background(Color.white)
                .forgroundColor(Color.blue)
                .bold()

            Text("init()")
                .forgroundColor(Color.cyan)

            HStack(spacing: 1) {
                Emoticon()
                Spacer(1)
                Text("Emoticon()  ← default :)")
                    .fontWeight(.thin)
                    .forgroundColor(.red)
            }

            Spacer()

            Text("init(eye:mouth:)  — cycling through all cases")
                .forgroundColor(Color.cyan)

            HStack(spacing: 1) {
                Emoticon(eye: eyes[eyeIndex], mouth: mouths[mouthIndex])
                Spacer(1)
                Text("eye: .\(eyes[eyeIndex])  mouth: .\(mouths[mouthIndex])")
                    .fontWeight(.thin)
                    .forgroundColor(.red)
            }

            Spacer()

            Text("EyesStyle cases")
                .forgroundColor(Color.cyan)

            Group {
                for eye in EyesStyle.allCases {
                    HStack(spacing: 1) {
                        Emoticon(eye: eye, mouth: .default)
                        Spacer(1)
                        Text(".\(eye)")
                            .fontWeight(.thin)
                            .forgroundColor(eye == eyes[eyeIndex] ? .green : .red)
                    }
                }
            }

            Spacer()

            Text("MouthStyle cases")
                .forgroundColor(Color.cyan)

            Group {
                for mouth in MouthStyle.allCases {
                    HStack(spacing: 1) {
                        Emoticon(eye: .default, mouth: mouth)
                        Spacer(1)
                        Text(".\(mouth)")
                            .fontWeight(.thin)
                            .forgroundColor(mouth == mouths[mouthIndex] ? .green : .red)
                    }
                }
            }
        }
    }
}
