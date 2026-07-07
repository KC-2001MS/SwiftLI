//
//  TextField.swift
//  sclt
//
//  Created by Keisuke Chinone on 2026/07/07.
//

import Foundation
import ArgumentParser
import SwiftLI

/// A full-screen sample that exercises ``TextField``: two focusable, editable
/// fields with a live preview. Tab/Shift-Tab move focus, Enter submits, Ctrl-C
/// quits.
struct TextFieldCommand: AsyncParsableCommand, FullScreenViewableCommand {
    static let configuration = CommandConfiguration(
        commandName: "textfield",
        abstract: "Display of TextField structure",
        discussion: """
        An interactive form: type into the focused field, Tab / Shift-Tab to
        move focus, Enter to submit, Ctrl-C to quit.
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    enum Field: Hashable { case name, email }

    @State var name = ""
    @State var email = ""
    @State var submitted = false
    @FocusState var focus: Field?

    mutating func run() async throws {
        startBodyRendering()
        // The fields collect input on their own; stay alive until Ctrl-C.
        await waitUntilInterrupted()
        stopBodyRendering()
        // Back on the normal screen, echo what was captured.
        print("name: \(name)")
        print("email: \(email)")
    }

    var body: some View {
        Group {
            Text(" TextField ")
                .bold()
                .forgroundColor(.black)
                .background(.cyan)

            Spacer()

            Text("Tab: move focus   Enter on Name: jump to Email   Ctrl-C: quit")
                .forgroundColor(.eight_bit(240))

            Spacer()

            HStack(spacing: 1) {
                Text("Name  :")
                // Enter on the name field programmatically moves focus to email.
                TextField("Enter your name", text: $name, onSubmit: { focus = .email })
                    .focused($focus, equals: .name)
            }
            HStack(spacing: 1) {
                Text("Email :")
                TextField("Enter your email", text: $email, onSubmit: { submitted = true })
                    .focused($focus, equals: .email)
            }

            Spacer()

            let focusName = focus == .name ? "Name" : (focus == .email ? "Email" : "none")
            Text("Focused: \(focusName)").forgroundColor(.cyan)
            if submitted {
                Text("Submitted: \(name) <\(email)>").forgroundColor(.green).bold()
            } else {
                Text("Preview: \(name) <\(email)>").forgroundColor(.yellow)
            }
        }
    }
}
