//
//  TimelineView.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/07.
//

import Foundation

/// A view that updates its content on a schedule, mirroring SwiftUI's
/// `TimelineView`.
///
/// `TimelineView` rebuilds its content every time its ``TimelineSchedule``
/// says to, passing the current date through a ``Context``. It plugs directly
/// into SwiftLI's reactive runtime: after each redraw it arms a one-shot timer
/// for the schedule's next date, and when that fires it triggers a re-render —
/// so the timeline advances on its own without any manual `@State` plumbing.
///
/// ## A live clock
///
/// ```swift
/// @main
/// struct ClockApp: CLIApp {
///     var body: [any View] {
///         TimelineView(.periodic(from: .now, by: 1)) { context in
///             Text("Now: \(context.date)")
///         }
///     }
/// }
/// ```
///
/// ## An animated spinner
///
/// ```swift
/// TimelineView(.animation) { context in
///     let frame = Int(context.date.timeIntervalSinceReferenceDate * 10) % 4
///     Text(["|", "/", "-", "\\"][frame])
/// }
/// ```
///
/// > Note: Updates only occur while a reactive runtime is active (a ``CLIApp``
/// > or a ``InlineCommand``/``FullScreenCommand`` that called `startBodyRendering()`). Rendered
/// > once outside that context, a `TimelineView` simply shows its content for
/// > the current date.
/// The information handed to a ``TimelineView``'s content closure on each
/// update, mirroring SwiftUI's `TimelineView.Context`.
public struct TimelineViewContext: Sendable {
    /// The date for which the content is being generated.
    public let date: Date
    /// How frequently the enclosing schedule updates.
    public let cadence: Cadence

    /// The update frequency of a ``TimelineView``. Alias of ``TimelineCadence``.
    public typealias Cadence = TimelineCadence
}

/// A view that updates its content on a schedule, mirroring SwiftUI's `TimelineView`.
///
/// `TimelineView` rebuilds its content every time its ``TimelineSchedule`` fires,
/// passing the current date through a ``Context``. Use the ``init(_:content:)``
/// initializer with any ``TimelineSchedule`` — such as `.periodic(from:by:)` or
/// `.animation` — and return terminal views from the content closure.
public struct TimelineView<Schedule: TimelineSchedule, Content: View>: View {

    /// The information handed to the content closure on each update.
    public typealias Context = TimelineViewContext

    let style: TextStyle
    let schedule: Schedule
    let content: (Context) -> Content

    /// Creates a timeline view.
    /// - Parameters:
    ///   - schedule: The ``TimelineSchedule`` that dictates when to update.
    ///   - content: A ``ViewBuilder`` closure that builds the content for a
    ///     given ``Context``.
    public init(
        _ schedule: Schedule,
        @ViewBuilder content: @escaping (Context) -> Content
    ) {
        self.style = .plain
        self.schedule = schedule
        self.content = content
    }

    init(
        style: TextStyle,
        schedule: Schedule,
        content: @escaping (Context) -> Content
    ) {
        self.style = style
        self.schedule = schedule
        self.content = content
    }

    /// The view's content, rendered for the current date at the time of layout.
    public var body: some View {
        EmptyView()
    }

    @_spi(RenderingInternals)
    public func applyingStyle(_ style: TextStyle) -> Self {
        TimelineView(style: self.style.inheriting(style), schedule: schedule, content: content)
    }

    /// Lowers the content for the current date, and arms the next update.
    ///
    /// Each layout pass:
    /// 1. Reads the current date and builds the content ``Context``.
    /// 2. Asks the coordinator to schedule a redraw at the schedule's next
    ///    date (coalesced by ``TimelineSchedule/timelineKey``).
    /// 3. Returns the lowered content, cascading any accumulated style.
    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        let now = Date()
        if let next = schedule.nextDate(after: now) {
            TimelineCoordinator.shared.arm(key: schedule.timelineKey, fireAt: next)
        }
        let context = Context(date: now, cadence: schedule.cadence)
        let node = content(context).makeNode()
        return style.isPlain ? node : node.applyingStyle(style)
    }
}

// MARK: - TimelineCoordinator

/// Owns the one-shot timers that drive every active ``TimelineView``.
///
/// A single armed timer per ``TimelineSchedule/timelineKey`` is kept at a time.
/// When it fires, the coordinator clears it and triggers a redraw through
/// whichever renderer is active; the ensuing layout pass re-arms the next
/// timer, so the timeline perpetuates itself without stacking timers.
final class TimelineCoordinator: @unchecked Sendable {
    static let shared = TimelineCoordinator()

    private let lock = NSLock()
    private var timers: [String: DispatchSourceTimer] = [:]

    private init() {}

    /// Arms a one-shot timer for `key` to fire at `fireAt`, unless one is
    /// already pending for that key (in which case the existing cadence is
    /// preserved).
    func arm(key: String, fireAt: Date) {
        lock.lock()
        // A timer is already counting down for this key — leave it alone so an
        // unrelated redraw doesn't reset the timeline's cadence.
        if timers[key] != nil {
            lock.unlock()
            return
        }
        let delay = Swift.max(fireAt.timeIntervalSinceNow, 0)
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + delay)
        timer.setEventHandler {
            TimelineCoordinator.shared.fire(key: key)
        }
        timers[key] = timer
        lock.unlock()
        timer.resume()
    }

    /// Handles a timer firing: clears it, then requests a redraw.
    private func fire(key: String) {
        lock.lock()
        timers[key]?.cancel()
        timers[key] = nil
        lock.unlock()

        // Route through both redraw paths, exactly like a `@State` mutation:
        // the full-screen CLIApp runtime and any inline command.
        AppRuntime.shared?.scheduleRender()
        StateObserverRegistry.shared.notifyChange()
    }

    /// Whether any timeline timer is counting down. While one is armed the
    /// display will change again, so an inline session's default `run()`
    /// stays alive.
    var hasArmedTimers: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !timers.isEmpty
    }

    /// Cancels every armed timer. Called when a runtime tears down so stale
    /// timers don't fire into a finished app.
    func reset() {
        lock.lock()
        let all = timers.values
        timers.removeAll()
        lock.unlock()
        for t in all { t.cancel() }
    }
}
