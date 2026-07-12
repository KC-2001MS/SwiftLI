//
//  TimelineSchedule.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/07.
//

import Foundation

/// How often a ``TimelineView`` updates, mirroring SwiftUI's `Context.Cadence`.
///
/// A schedule reports the cadence it drives so content can adapt how much
/// detail it shows (for example, hiding a seconds field when only updating
/// once per minute).
public enum TimelineCadence: Sendable, Equatable {
    /// Updates happen many times per second (animation-rate).
    case live
    /// Updates happen about once per second.
    case seconds
    /// Updates happen about once per minute.
    case minutes
}

/// A type that provides the dates at which a ``TimelineView`` should update,
/// mirroring SwiftUI's `TimelineSchedule`.
///
/// SwiftLI drives updates lazily: rather than enumerating every future date, a
/// schedule only needs to answer "what is the next date after this one?". The
/// ``TimelineView`` re-arms a one-shot timer for that date after each redraw,
/// so the sequence advances on its own.
public protocol TimelineSchedule {
    /// The next update date strictly after `date`, or `nil` to stop updating.
    func nextDate(after date: Date) -> Date?

    /// The cadence this schedule drives. Defaults to ``TimelineCadence/seconds``.
    var cadence: TimelineCadence { get }

    /// A key that is **stable across re-renders** and identifies logically
    /// equal schedules, so the runtime coalesces their timers instead of
    /// arming a fresh one on every layout pass.
    var timelineKey: String { get }
}

public extension TimelineSchedule {
    /// The default cadence for schedules that do not override it: ``TimelineCadence/seconds``.
    var cadence: TimelineCadence { .seconds }
}

// MARK: - PeriodicTimelineSchedule

/// A schedule that updates at a regular interval starting from a given date.
public struct PeriodicTimelineSchedule: TimelineSchedule, Sendable {
    let startDate: Date
    let interval: TimeInterval

    /// Creates a periodic schedule.
    /// - Parameters:
    ///   - startDate: The reference date the cadence is measured from.
    ///   - interval: The seconds between updates. Must be greater than zero.
    public init(from startDate: Date, by interval: TimeInterval) {
        self.startDate = startDate
        self.interval = interval
    }

    /// Returns the next update date strictly after `date`, aligned to the periodic cadence.
    /// - Parameter date: The reference date to advance from.
    /// - Returns: The next scheduled date, or `nil` if `interval` is not greater than zero.
    public func nextDate(after date: Date) -> Date? {
        guard interval > 0 else { return nil }
        // Smallest integer n such that startDate + n*interval is strictly after `date`.
        let steps = (date.timeIntervalSince(startDate) / interval).rounded(.down) + 1
        return startDate.addingTimeInterval(steps * interval)
    }

    /// The cadence of this schedule: ``TimelineCadence/live`` for sub-second intervals, ``TimelineCadence/seconds`` otherwise.
    public var cadence: TimelineCadence { interval < 1 ? .live : .seconds }

    // Intentionally keyed on the interval only (not startDate): an inline
    // `.periodic(from: .now, by: 1)` recomputes `.now` every render, and keying
    // on it would arm a new timer each pass. The interval is what defines the
    // cadence, so equal-interval timelines safely share one timer.
    /// A stable key derived from the interval that allows equal-interval timelines to share a single timer.
    public var timelineKey: String { "periodic:\(interval)" }
}

// MARK: - EveryMinuteTimelineSchedule

/// A schedule that updates once per minute, aligned to the top of the minute.
public struct EveryMinuteTimelineSchedule: TimelineSchedule, Sendable {
    /// Creates an every-minute schedule.
    public init() {}

    /// Returns the next clock-aligned minute boundary strictly after `date`.
    /// - Parameter date: The reference date to advance from.
    /// - Returns: The start of the next minute after `date`.
    public func nextDate(after date: Date) -> Date? {
        let t = date.timeIntervalSinceReferenceDate
        let next = (t / 60).rounded(.down) * 60 + 60
        return Date(timeIntervalSinceReferenceDate: next)
    }

    /// The cadence of this schedule: ``TimelineCadence/minutes``.
    public var cadence: TimelineCadence { .minutes }
    /// A stable key that identifies this schedule so all every-minute timelines share one timer.
    public var timelineKey: String { "everyMinute" }
}

// MARK: - AnimationTimelineSchedule

/// A schedule that updates at animation rate, mirroring SwiftUI's `.animation`.
public struct AnimationTimelineSchedule: TimelineSchedule, Sendable {
    let minimumInterval: TimeInterval
    let paused: Bool

    /// Creates an animation schedule.
    /// - Parameters:
    ///   - minimumInterval: The shortest interval between updates, in seconds.
    ///     Defaults to `1/30` (30 fps).
    ///   - paused: When `true`, updates stop until the view is rebuilt with
    ///     `paused == false`.
    public init(minimumInterval: TimeInterval = 1.0 / 30.0, paused: Bool = false) {
        self.minimumInterval = minimumInterval
        self.paused = paused
    }

    /// Returns the next update date `minimumInterval` seconds after `date`, or `nil` when paused.
    /// - Parameter date: The reference date to advance from.
    /// - Returns: The next scheduled date, or `nil` if the schedule is paused.
    public func nextDate(after date: Date) -> Date? {
        paused ? nil : date.addingTimeInterval(minimumInterval)
    }

    /// The cadence of this schedule: ``TimelineCadence/live``.
    public var cadence: TimelineCadence { .live }
    /// A stable key derived from `minimumInterval` that allows equal-rate animation timelines to share one timer.
    public var timelineKey: String { "animation:\(minimumInterval)" }
}

// MARK: - Convenience factories (SwiftUI-style leading-dot syntax)

public extension TimelineSchedule where Self == PeriodicTimelineSchedule {
    /// A schedule that updates every `interval` seconds starting from `startDate`.
    static func periodic(from startDate: Date, by interval: TimeInterval) -> PeriodicTimelineSchedule {
        PeriodicTimelineSchedule(from: startDate, by: interval)
    }
}

public extension TimelineSchedule where Self == EveryMinuteTimelineSchedule {
    /// A schedule that updates at the start of every minute.
    static var everyMinute: EveryMinuteTimelineSchedule { EveryMinuteTimelineSchedule() }
}

public extension TimelineSchedule where Self == AnimationTimelineSchedule {
    /// A schedule that updates at animation rate (30 fps).
    static var animation: AnimationTimelineSchedule { AnimationTimelineSchedule() }

    /// A schedule that updates at animation rate with a custom minimum interval.
    static func animation(minimumInterval: TimeInterval? = nil, paused: Bool = false) -> AnimationTimelineSchedule {
        AnimationTimelineSchedule(minimumInterval: minimumInterval ?? (1.0 / 30.0), paused: paused)
    }
}
