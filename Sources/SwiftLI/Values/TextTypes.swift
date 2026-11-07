//
//  TextTypes.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/11/08.
//

import Foundation

/// How the lines of a multi-line ``Text`` align within the text's width,
/// mirroring SwiftUI's `TextAlignment`.
///
/// Opaque, like every SwiftLI value type: compare with `==`, never switch.
public struct TextAlignment: Equatable, Hashable, Sendable {
    private enum Kind: Hashable, Sendable { case leading, center, trailing }
    private let kind: Kind

    /// Lines start at the leading edge (the default).
    public static let leading = TextAlignment(kind: .leading)
    /// Lines are centred within the widest line.
    public static let center = TextAlignment(kind: .center)
    /// Lines end at the trailing edge.
    public static let trailing = TextAlignment(kind: .trailing)
}

public extension Text {
    /// Where a line-limited text drops characters, mirroring SwiftUI's
    /// `Text.TruncationMode`.
    struct TruncationMode: Equatable, Hashable, Sendable {
        private enum Kind: Hashable, Sendable { case head, tail, middle }
        private let kind: Kind

        /// Drop the start: `…end of the text`.
        public static let head = TruncationMode(kind: .head)
        /// Drop the end: `start of the text…` (the default).
        public static let tail = TruncationMode(kind: .tail)
        /// Drop the centre: `start…end`.
        public static let middle = TruncationMode(kind: .middle)
    }

    /// How a date is rendered by ``Text/init(_:style:)``, mirroring SwiftUI's
    /// `Text.DateStyle`.
    struct DateStyle: Equatable, Sendable {
        enum Kind: Equatable, Sendable { case time, date, relative, offset, timer }
        let kind: Kind

        /// The time only (`9:41 AM`).
        public static let time = DateStyle(kind: .time)
        /// The date only (`Jun 3, 2026`).
        public static let date = DateStyle(kind: .date)
        /// The interval to now in words (`3 hours ago`, `in 2 days`).
        public static let relative = DateStyle(kind: .relative)
        /// The signed interval to now (`+3 hours`, `-2 minutes`).
        public static let offset = DateStyle(kind: .offset)
        /// A running clock of the interval to now (`1:02:45`).
        public static let timer = DateStyle(kind: .timer)

        /// The text for `date` right now.
        func format(_ date: Date) -> String {
            switch kind {
            case .time:
                return date.formatted(date: .omitted, time: .shortened)
            case .date:
                return date.formatted(date: .abbreviated, time: .omitted)
            case .relative:
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .full
                return formatter.localizedString(for: date, relativeTo: Date())
            case .offset:
                let interval = date.timeIntervalSinceNow
                let formatter = DateComponentsFormatter()
                formatter.allowedUnits = [.day, .hour, .minute, .second]
                formatter.maximumUnitCount = 1
                formatter.unitsStyle = .full
                let magnitude = formatter.string(from: abs(interval)) ?? "0 seconds"
                return (interval < 0 ? "-" : "+") + magnitude
            case .timer:
                let formatter = DateComponentsFormatter()
                formatter.allowedUnits = [.hour, .minute, .second]
                formatter.zeroFormattingBehavior = .dropLeading
                formatter.unitsStyle = .positional
                return formatter.string(from: abs(date.timeIntervalSinceNow)) ?? "0:00"
            }
        }

        /// How often a live session should redraw the text so it stays
        /// current, or `nil` for a style that never changes.
        var refreshInterval: TimeInterval? {
            switch kind {
            case .time, .date: return nil
            case .relative, .offset: return 60
            case .timer: return 1
            }
        }
    }
}
