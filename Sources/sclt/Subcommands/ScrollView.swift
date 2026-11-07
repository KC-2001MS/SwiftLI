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
        A 40×10 frame over a 50-row list (scrollbar pinned to the frame's
        trailing column), a 40×2 frame over one wide row (scrollbar on the
        frame's bottom row), and a 40×3 viewport whose bar is hidden with
        .scrollIndicators(.hidden). ↑/↓ or ←/→ scroll one step, Space pages,
        Home/End jump to the ends, Tab moves between the viewports. The mouse
        wheel scrolls the vertical viewport under the pointer; the horizontal
        one follows a horizontal swipe (on terminals that report one) or
        Shift + wheel (the only pointer gesture for it on Terminal.app).
        Ctrl-C quits.
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    // No run() — FullScreenCommand's default runs the session until Ctrl-C.

    var body: some Scene {
        NavigationStack {
            Text("Vertical — a 40×10 frame onto 50 rows:").foregroundStyle(.cyan)
                .navigationTitle("ScrollView")
                .navigationSubtitle("↑/↓ ←/→: scroll   Space: page   Home/End: jump   Tab: switch   Shift+wheel: sideways   Ctrl-C: quit")
            ScrollView {
                ForEach(0..<50) { i in
                    HStack(spacing: 1) {
                        Text(String(format: "%3d", i)).foregroundStyle(.eightBit(240))
                        Text("│").foregroundStyle(.cyan)
                        Text("List item number \(i)")
                    }
                }
            }
            .frame(width: 40, height: 10)

            Text("Horizontal — a 40×2 frame onto one wide row:").foregroundStyle(.cyan)
                .padding(.top, 1)
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(0..<26) { i in
                        Text(" \(Character(UnicodeScalar(65 + i)!))\(i) ")
                            .foregroundStyle(i % 2 == 0 ? .cyan : .primary)
                    }
                }
            }
            .frame(width: 40, height: 2)

            Text("Hidden indicators — .scrollIndicators(.hidden) on a 40×3 frame:").foregroundStyle(.cyan)
                .padding(.top, 1)
            ScrollView {
                ForEach(0..<12) { i in
                    Text("Quiet row \(i) — scrolls, but draws no bar")
                }
            }
            .frame(width: 40, height: 3)
            .scrollIndicators(.hidden)

            Divider()
                .padding(.top, 1)
            Text("Each bar sits at the far edge of its frame; the wheel follows the content")
                .foregroundStyle(.yellow)
        }
    }
}
