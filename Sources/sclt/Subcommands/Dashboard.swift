//
//  Dashboard.swift
//  sclt
//
//  Created by Keisuke Chinone on 2026/07/07.
//

import Foundation
import ArgumentParser
import SwiftLI

/// A full-screen sample that combines the basic views (``VStack``, ``HStack``,
/// ``Divider``, ``Text``, ``Spacer``, ``ForEach``) with ``ProgressView`` in a
/// single nested layout, to exercise a more complex full-screen composition.
struct DashboardCommand: FullScreenCommand {
    static let configuration = CommandConfiguration(
        commandName: "dashboard",
        abstract: "Full-screen dashboard combining basic views and ProgressView",
        discussion: """
        A complex full-screen layout: a title bar, a task list with per-task
        progress bars on the left, and overall stats on the right, all driven
        live by a single animated state value.
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    /// Drives the whole dashboard; incremented by the task in `body`.
    @State var tick: Int = 0

    @Environment(\.dismiss) var dismiss

    private var tasks: [String] { ["Fetch", "Resolve", "Build", "Test", "Package", "Upload"] }

    // No run() — the task in `body` animates the dashboard, then dismisses.

    // MARK: - Derived values

    /// Staggered 0…1 progress for each task, so they fill one after another.
    private func progress(for index: Int) -> Double {
        let start = Double(index) * 10.0
        let value = (Double(tick) - start) / 50.0
        return Swift.max(0.0, Swift.min(1.0, value))
    }

    private var completed: Int {
        (0..<tasks.count).filter { progress(for: $0) >= 1.0 }.count
    }

    private var overall: Double {
        let total = (0..<tasks.count).map { progress(for: $0) }.reduce(0, +)
        return total / Double(tasks.count)
    }

    /// Right-pads `text` with spaces to `width` columns for column alignment.
    private func pad(_ text: String, to width: Int) -> String {
        text.count >= width ? text : text + String(repeating: " ", count: width - text.count)
    }

    // MARK: - Body

    var body: some Scene {
        NavigationStack {
            // Two columns separated by a vertical divider.
            HStack(alignment: .top, spacing: 2) {
                // Left: task list, each row a label + its own progress bar.
                VStack(alignment: .leading) {
                    Text("Tasks").bold().underline().forgroundColor(.cyan)
                    ForEach(0..<tasks.count) { index in
                        HStack(spacing: 1) {
                            Text(pad(tasks[index], to: 9))
                            Gauge(value: progress(for: index)).frame(width: 18, alignment: .topLeading)
                        }
                    }
                }

                Divider()

                // Right: overall progress and live stats.
                VStack(alignment: .leading) {
                    Text("Overall").bold().underline().forgroundColor(.cyan)
                    Gauge(value: overall).frame(width: 24, alignment: .topLeading)
                    Text("Completed : \(completed)/\(tasks.count)").forgroundColor(.green)
                        .padding(.top, 1)
                    Text("Remaining : \(tasks.count - completed)").forgroundColor(.yellow)
                    Text("Tick      : \(tick)")
                    ProgressView(completed == tasks.count ? "Done" : "Working", phase: tick)
                        .padding(.top, 1)
                }
            }
                .navigationTitle("Dashboard")
                .task {
                    for _ in 0..<140 {
                        try? await Task.sleep(nanoseconds: 80_000_000)
                        tick += 1
                    }
                    dismiss()
                }

            Divider()
                .padding(.top, 1)
            Text("Ctrl+C to quit — resize the window to see the layout follow")
                .forgroundColor(.eight_bit(240))
        }
    }
}
