//
//  Sheet.swift
//  sclt
//
//  Created by Keisuke Chinone on 2026/07/11.
//

import Foundation
import ArgumentParser
import SwiftLI

/// A full-screen sample of ``View/sheet(isPresented:id:onDismiss:content:)``:
/// a button presents a modal card, and `dismiss()` inside the sheet closes it.
struct SheetCommand: FullScreenCommand {
    static let configuration = CommandConfiguration(
        commandName: "sheet",
        abstract: "Display of sheet",
        discussion: """
        A button presents a modal sheet in a rounded-border card. While the
        sheet is up its controls take focus; the Done button dismisses it via
        the environment's dismiss action. Ctrl-C quits.
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    @State var showsSheet = false
    @State var name = ""

    // No run() — FullScreenCommand's default runs the session until Ctrl-C.

    var body: some Scene {
        NavigationStack {
            Button("Edit name…") { showsSheet = true }
                .navigationTitle("Sheet")
                .navigationSubtitle("Return/Space: open   Tab: focus   Ctrl-C: quit")

            Text("name: \(name.isEmpty ? "(unset)" : name)")
                .forgroundColor(.yellow)
                .padding(.top, 1)
                .sheet(isPresented: $showsSheet) {
                    SheetContent(name: $name)
                }
        }
    }
}

/// The sheet's content: an editable field plus a Done button that closes the
/// sheet through `\.dismiss` (captured while the sheet is up).
private struct SheetContent: View {
    @Environment(\.dismiss) var dismiss
    let name: Binding<String>

    var body: some View {
        Text("Edit name").bold()
        TextField("Name", text: name)
        Button("Done") { [dismiss] in dismiss() }
    }
}
