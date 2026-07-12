//
//  Slider.swift
//  sclt
//
//  Created by Keisuke Chinone on 2026/07/11.
//

import Foundation
import ArgumentParser
import SwiftLI

/// A full-screen sample driving ``Slider``s with the keyboard. Arrows step
/// the value, Home/End jump to the ends, Tab moves focus.
struct SliderCommand: FullScreenCommand {
    static let configuration = CommandConfiguration(
        commandName: "slider",
        abstract: "Display of Slider",
        discussion: """
        Sliders bound to Double values. ←/↓ step down, →/↑ step up, Home/End
        jump to the minimum/maximum, Tab / Shift-Tab move focus, Ctrl-C quits.
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    @State var volume = 50.0
    @State var brightness = 0.8

    // No run() — FullScreenCommand's default runs the session until Ctrl-C.

    var body: some Scene {
        NavigationStack {
            Slider("Volume", value: $volume, in: 0...100, step: 5)
                .navigationTitle("Slider")
                .navigationSubtitle("←/→: step   Home/End: min/max   Tab: focus   Ctrl-C: quit")
            // Slider-specific modifier: sliderStyle picks the track's
            // appearance (.automatic is the filled track with a round thumb).
            Slider("Brightness", value: $brightness)
                .sliderStyle(.automatic)

            Divider()
                .padding(.top, 1)
            Text("volume: \(Int(volume))   brightness: \(Int(brightness * 100))%")
                .forgroundColor(.yellow)
        }
    }
}
