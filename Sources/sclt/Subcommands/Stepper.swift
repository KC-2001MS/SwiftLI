//
//  Stepper.swift
//  sclt
//
//  Created by Keisuke Chinone on 2026/07/10.
//

import Foundation
import ArgumentParser
import SwiftLI

/// A full-screen sample for ``Stepper``. Tab moves focus between the `[-]` and
/// `[+]` buttons; Return / Space step the value; Ctrl-C quits.
struct StepperCommand: FullScreenCommand {
    static let configuration = CommandConfiguration(
        commandName: "stepper",
        abstract: "Display of Stepper structure",
        discussion: """
        Steppers bound to Int and Double values, plus a closure-driven one.
        Tab / Shift-Tab move focus, Return or Space press the focused button,
        Ctrl-C quits.
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    @State var quantity = 1
    @State var volume = 0.5
    @State var zoom = 1

    // No run() — FullScreenCommand's default runs the session until Ctrl-C.

    var body: some Scene {
        NavigationStack {
            Stepper("Quantity (1...10)", value: $quantity, in: 1...10)
                .navigationTitle("Stepper")
                .navigationSubtitle("Tab: focus   Return/Space: step   Ctrl-C: quit")
            Stepper("Volume (0...1, step 0.1)", value: $volume, in: 0.0...1.0, step: 0.1)
            Stepper("Zoom (closures, ×2 / ÷2)", id: "Zoom") {
                zoom *= 2
            } onDecrement: {
                zoom = Swift.max(1, zoom / 2)
            }

            Divider()
                .padding(.top, 1)
            Text("quantity: \(quantity)   volume: \(volume)   zoom: \(zoom)x")
                .forgroundColor(.yellow)
        }
    }
}
