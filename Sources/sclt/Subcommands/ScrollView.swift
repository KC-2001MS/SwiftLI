//
//  ScrollView.swift
//  sclt
//
//  Created by Keisuke Chinone on 2026/07/07.
//

import Foundation
import ArgumentParser
import SwiftLI

/// A full-screen sample for ``ScrollView``: a tall list through a short
/// vertical viewport, and a wide row through a narrow horizontal one.
/// Arrow keys scroll the focused viewport; Tab switches; Ctrl-C quits.
struct ScrollViewCommand: FullScreenCommand {
    static let configuration = CommandConfiguration(
        commandName: "scrollview",
        abstract: "Display of ScrollView structure",
        discussion: """
        A fixed-height viewport over a 50-row list (scrollbar pinned to the
        trailing edge) and a fixed-width viewport over one wide row (scrollbar
        along the bottom edge). ↑/↓ or ←/→ scroll one step, Space pages,
        Home/End jump to the ends, Tab moves between the viewports. Ctrl-C
        quits.
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    // No run() — FullScreenCommand's default runs the session until Ctrl-C.

    var body: some Scene {
        NavigationStack {
            Text("Vertical — a 10-row window onto 50 rows:").forgroundColor(.cyan)
                .navigationTitle("ScrollView")
                .navigationSubtitle("↑/↓ or ←/→: scroll   Space: page   Home/End: jump   Tab: switch   Ctrl-C: quit")
            ScrollView(height: 10) {
                ForEach(0..<50) { i in
                    HStack(spacing: 1) {
                        Text(String(format: "%3d", i)).forgroundColor(.eight_bit(240))
                        Text("│").forgroundColor(.cyan)
                        Text("List item number \(i)")
                    }
                }
            }

            Text("Horizontal — a 40-column window onto one wide row:").forgroundColor(.cyan)
                .padding(.top, 1)
            ScrollView(width: 40) {
                HStack(spacing: 0) {
                    ForEach(0..<26) { i in
                        Text(" \(Character(UnicodeScalar(65 + i)!))\(i) ")
                            .forgroundColor(i % 2 == 0 ? .cyan : .primary)
                    }
                }
            }

            Divider()
                .padding(.top, 1)
            Text("Both scrollbars are solid strips with half-cell end caps")
                .forgroundColor(.yellow)
        }
    }
}
