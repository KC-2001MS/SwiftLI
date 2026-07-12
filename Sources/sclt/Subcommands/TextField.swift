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
struct TextFieldCommand: FullScreenCommand {
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

    // No run() — the fields collect input on their own; FullScreenCommand's
    // default runs the session until Ctrl-C.

    var body: some Scene {
        NavigationStack {
            HStack(spacing: 1) {
                Text("Name  :")
                // Enter on the name field programmatically moves focus to email.
                TextField("Enter your name", text: $name, onSubmit: { focus = .email })
                    .focused($focus, equals: .name)
            }
                .navigationTitle("TextField")
                .navigationSubtitle("Tab: move focus   Enter on Name: jump to Email   Ctrl-C: quit")
            HStack(spacing: 1) {
                Text("Email :")
                // TextField-specific modifier: textFieldStyle picks the field
                // chrome (.automatic is the built-in style).
                TextField("Enter your email", text: $email, onSubmit: { submitted = true })
                    .textFieldStyle(.automatic)
                    .focused($focus, equals: .email)
            }

            let focusName = focus == .name ? "Name" : (focus == .email ? "Email" : "none")
            Text("Focused: \(focusName)").forgroundColor(.cyan)
                .padding(.top, 1)
            if submitted {
                Text("Submitted: \(name) <\(email)>").forgroundColor(.green).bold()
            } else {
                Text("Preview: \(name) <\(email)>").forgroundColor(.yellow)
            }
        }
    }
}
