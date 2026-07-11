//
//  Environment.swift
//  sclt
//
//  Created by Keisuke Chinone on 2026/07/10.
//

import Foundation
import ArgumentParser
import SwiftLI

/// A full-screen sample for the `@Environment` values: `\.maxWidth` read at
/// several scopes (and layouts that adapt to it), plus `\.colorScheme` with an
/// override. Resize the window to watch every value follow it.
struct EnvironmentCommand: FullScreenCommand {
    static let configuration = CommandConfiguration(
        commandName: "environment",
        abstract: "Display of the @Environment values (maxWidth, colorScheme)",
        discussion: """
        Reads \\.maxWidth at the top level and inside width-narrowing scopes,
        draws rules that always span their scope, switches a layout between
        wide and compact based on the available width, and shows the detected
        and overridden \\.colorScheme. Resize the window to see the values
        update. Ctrl-C quits.
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    // No run() — FullScreenCommand's default runs the session until Ctrl-C.

    var body: some Scene {
        NavigationStack {
            Text("maxWidth at each scope:").forgroundColor(.cyan)
                .navigationTitle("@Environment")
                .navigationSubtitle("Resize the window — every value below follows it")
            WidthReadout(label: "top level")
            WidthReadout(label: "inside frame(width: 40)")
                .frame(width: 40, alignment: .topLeading)
            WidthReadout(label: "inside padding + border")
                .padding(.horizontal, 2)
                .border(.rounded, color: .eight_bit(240))

            Text("A rule that always spans its scope:").forgroundColor(.cyan)
                .padding(.top, 1)
            FullWidthRule()
            FullWidthRule().frame(width: 30, alignment: .topLeading)

            Text("Layout that adapts to the available width:").forgroundColor(.cyan)
                .padding(.top, 1)
            ResponsiveSummary()
            ResponsiveSummary().frame(width: 30, alignment: .topLeading)

            Text("colorScheme:").forgroundColor(.cyan)
                .padding(.top, 1)
            SchemeReadout(label: "detected")
            SchemeReadout(label: "forced .light")
                .environment(\.colorScheme, .light)

            Divider()
                .padding(.top, 1)
            Text("Ctrl-C to quit").forgroundColor(.eight_bit(240))
        }
    }
}

/// Shows the `\.maxWidth` visible at its position in the tree.
private struct WidthReadout: View {
    let label: String
    @Environment(\.maxWidth) var maxWidth

    var body: some View {
        HStack(spacing: 1) {
            Text("\(label):").forgroundColor(.eight_bit(245))
            Text("\(maxWidth) cols").bold()
        }
    }
}

/// A horizontal rule exactly as wide as the columns its scope allows.
private struct FullWidthRule: View {
    @Environment(\.maxWidth) var maxWidth

    var body: some View {
        Text(repeating: "─", count: maxWidth).forgroundColor(.eight_bit(240))
    }
}

/// Switches between a wide (one row) and a compact (stacked) layout based on
/// the width its scope provides — terminal-flavoured size classes.
private struct ResponsiveSummary: View {
    @Environment(\.maxWidth) var maxWidth

    var body: some View {
        if maxWidth >= 40 {
            HStack(spacing: 3) {
                Text("CPU 42%").forgroundColor(.green)
                Text("MEM 61%").forgroundColor(.yellow)
                Text("DISK 18%").forgroundColor(.cyan)
            }
        } else {
            VStack(alignment: .leading) {
                Text("CPU 42%").forgroundColor(.green)
                Text("MEM 61%").forgroundColor(.yellow)
                Text("DISK 18%").forgroundColor(.cyan)
            }
        }
    }
}

/// Shows the `\.colorScheme` visible at its position in the tree.
private struct SchemeReadout: View {
    let label: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 1) {
            Text("\(label):").forgroundColor(.eight_bit(245))
            Text(colorScheme == .dark ? "dark" : "light").bold()
        }
    }
}
