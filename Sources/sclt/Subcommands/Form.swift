//
//  Form.swift
//  sclt
//
//  Created by Keisuke Chinone on 2026/07/11.
//

import Foundation
import ArgumentParser
import SwiftLI

/// A full-screen sample composing a ``Form`` of ``Section``s that mix text
/// fields, a toggle, a picker, and a slider.
struct FormCommand: FullScreenCommand {
    static let configuration = CommandConfiguration(
        commandName: "form",
        abstract: "Display of Form and Section",
        discussion: """
        A Form groups sections of data-entry controls: bold section headers,
        indented rows, and a blank line between sections. Tab / Shift-Tab move
        focus through the controls, Ctrl-C quits.
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    @State var name = ""
    @State var email = ""
    @State var notifies = true
    @State var theme = 0

    // No run() — FullScreenCommand's default runs the session until Ctrl-C.

    var body: some Scene {
        NavigationStack {
            Form {
                Section("Account") {
                    TextField("Name", text: $name)
                    TextField("Email", text: $email)
                }
                Section {
                    Toggle("Notifications", isOn: $notifies)
                    Picker("Theme", selection: $theme, options: ["System", "Light", "Dark"])
                } header: {
                    Text("Options")
                } footer: {
                    Text("You can change these later.")
                }
            }
                .navigationTitle("Form")
                .navigationSubtitle("Tab: focus   type to edit   Ctrl-C: quit")

            Divider()
                .padding(.top, 1)
            Text("name: \(name)   email: \(email)   notifications: \(notifies ? "on" : "off")")
                .forgroundColor(.yellow)
        }
    }
}
