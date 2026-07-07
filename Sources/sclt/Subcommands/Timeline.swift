//
//  Timeline.swift
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
struct TimelineCommand: AsyncParsableCommand, FullScreenViewableCommand {
    static let configuration = CommandConfiguration(
        commandName: "timeline",
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

    mutating func run() async throws {
        startBodyRendering()
        // The timelines redraw themselves; just stay alive for the demo, then
        // tear down. (Ctrl+C also exits cleanly.)
        try await Task.sleep(nanoseconds: 20_000_000_000)
        stopBodyRendering()
    }

    var body: some View {
        Group {
            Text(" TimelineView ")
                .bold()
                .forgroundColor(.black)
                .background(.cyan)

            Spacer()

            // 1) A clock that ticks once per second.
            Text("Clock — .periodic(by: 1)").forgroundColor(.cyan)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                HStack(spacing: 1) {
                    Text("  \(Self.clock.string(from: context.date))").bold()
                    Text("[\(cadenceName(context.cadence))]").forgroundColor(.eight_bit(240))
                }
            }

            Spacer()

            // 2) An animation-rate spinner (~30 fps) driven purely by the date.
            Text("Spinner — .animation").forgroundColor(.cyan)
            TimelineView(.animation) { context in
                let frames = ProgressSpinner.frames
                let index = Int(context.date.timeIntervalSinceReferenceDate * 12) % frames.count
                HStack(spacing: 1) {
                    Text("  \(frames[index])").forgroundColor(.green)
                    Text("working...")
                }
            }

            Spacer()

            // 3) A seconds bar that sweeps 0…59 within each minute.
            Text("Seconds sweep — .periodic(by: 1)").forgroundColor(.cyan)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let second = Calendar.current.component(.second, from: context.date)
                let filled = String(repeating: "█", count: second)
                let empty = String(repeating: "░", count: 60 - second)
                Text("  \(filled)\(empty) \(second)s")
            }

            Spacer()
            Divider()
            Text("Each row updates on its own cadence — Ctrl+C to quit")
                .forgroundColor(.eight_bit(240))
        }
    }
}
