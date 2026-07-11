//
//  TimelineView.swift
//  sclt
//
//  Created by Keisuke Chinone on 2026/07/07.
//

import Foundation
import ArgumentParser
import SwiftLI

/// A full-screen sample that exercises ``TimelineView`` with several schedules.
///
/// Unlike the other demos, this command mutates **no** `@State`: each
/// `TimelineView` drives its own redraws through its ``TimelineSchedule``, so
/// `run()` only has to keep the process alive while the timelines tick.
struct TimelineViewCommand: FullScreenCommand {
    static let configuration = CommandConfiguration(
        commandName: "timelineview",
        abstract: "Display of TimelineView structure",
        discussion: """
        Command to check the display of TimelineView: a per-second clock, an
        animation-rate spinner, and a once-per-minute schedule, each updating on
        its own cadence.
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    /// Formats the clock timeline's date as `HH:mm:ss`.
    private static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private func cadenceName(_ cadence: TimelineCadence) -> String {
        switch cadence {
        case .live:    return "live"
        case .seconds: return "seconds"
        case .minutes: return "minutes"
        }
    }

    @Environment(\.dismiss) var dismiss

    // No run() — the timelines redraw themselves; the task in `body` bounds
    // the demo's duration, then dismisses.

    var body: some Scene {
        NavigationStack {
            // 1) A clock that ticks once per second.
            Text("Clock — .periodic(by: 1)").forgroundColor(.cyan)
                .navigationTitle("TimelineView")
                .task {
                    // Stay alive for the demo, then dismiss. (Ctrl+C exits early.)
                    try? await Task.sleep(nanoseconds: 20_000_000_000)
                    dismiss()
                }
            TimelineView(.periodic(from: .now, by: 1)) { context in
                HStack(spacing: 1) {
                    Text("  \(Self.clock.string(from: context.date))").bold()
                    Text("[\(cadenceName(context.cadence))]").forgroundColor(.eight_bit(240))
                }
            }

            // 2) An animation-rate spinner (~30 fps) driven purely by the date.
                .padding(.top, 1)
            Text("Spinner — .animation").forgroundColor(.cyan)
            TimelineView(.animation) { context in
                let frames = ProgressSpinner.frames
                let index = Int(context.date.timeIntervalSinceReferenceDate * 12) % frames.count
                HStack(spacing: 1) {
                    Text("  \(frames[index])").forgroundColor(.green)
                    Text("working...")
                }
            }

            // 3) A seconds bar that sweeps 0…59 within each minute.
                .padding(.top, 1)
            Text("Seconds sweep — .periodic(by: 1)").forgroundColor(.cyan)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let second = Calendar.current.component(.second, from: context.date)
                let filled = String(repeating: "█", count: second)
                let empty = String(repeating: "░", count: 60 - second)
                Text("  \(filled)\(empty) \(second)s")
            }

            Divider()
                .padding(.top, 1)
            Text("Each row updates on its own cadence — Ctrl+C to quit")
                .forgroundColor(.eight_bit(240))
        }
    }
}
