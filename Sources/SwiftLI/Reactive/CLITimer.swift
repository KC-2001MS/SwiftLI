//
//  CLITimer.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2024/05/27.
//

import Foundation

/// A utility for scheduling periodic updates from within a ``CLIApp``.
///
/// `CLITimer` wraps `DispatchSourceTimer` and provides a simple interface for
/// running a closure at a fixed interval. Use it to drive animations, progress
/// updates, or any other time-based state changes.
///
/// ## Basic Usage
///
/// Create a timer in your ``CLIApp``'s `init`, then start it inside an
/// `onAppear` modifier or directly in `init`. The closure you provide should
/// update a `@State` property, which automatically triggers a re-render.
///
/// ```swift
/// @main
/// struct CountdownApp: CLIApp {
///     @State var remaining: Int = 10
///     let timer = CLITimer(interval: 1.0)
///
///     init() {
///         // Timer will start after the runtime begins its loop
///     }
///
///     var body: [View] {
///         Text("Time remaining: \(remaining)s").newLine()
///     }
/// }
/// ```
///
/// - Note: The timer fires on the main queue by default, which is the same
///   queue where the render loop runs. This ensures state mutations and renders
///   are naturally serialized without additional locking.
public final class CLITimer: @unchecked Sendable {
    private var source: DispatchSourceTimer?
    private let interval: TimeInterval
    private let queue: DispatchQueue
    private let lock = NSLock()
    /// Whether this timer is currently counted as a session redraw driver.
    /// A running timer keeps an inline session's default `run()` alive.
    private var countsAsDriver = false

    /// Creates a timer that fires at the specified interval.
    /// - Parameters:
    ///   - interval: The time between firings, in seconds.
    ///   - queue: The dispatch queue on which `action` is called.
    ///     Defaults to `.main`.
    public init(interval: TimeInterval, queue: DispatchQueue = .main) {
        self.interval = interval
        self.queue = queue
    }

    /// Starts the timer and calls `action` repeatedly at the configured interval.
    ///
    /// If the timer is already running, it is stopped and restarted with the
    /// new action.
    ///
    /// - Parameter action: The closure to execute on each timer tick.
    public func start(action: @escaping @Sendable () -> Void) {
        stop()
        let newSource = DispatchSource.makeTimerSource(queue: queue)
        newSource.schedule(deadline: .now() + interval, repeating: interval)
        newSource.setEventHandler(handler: action)
        newSource.resume()
        lock.lock()
        source = newSource
        let becameDriver = !countsAsDriver
        countsAsDriver = true
        lock.unlock()
        if becameDriver { SessionLifecycle.shared.driverBegan() }
    }

    /// Stops the timer. Calling this method is idempotent.
    public func stop() {
        lock.lock()
        let s = source
        source = nil
        let wasDriver = countsAsDriver
        countsAsDriver = false
        lock.unlock()
        s?.cancel()
        if wasDriver { SessionLifecycle.shared.driverEnded() }
    }

    deinit {
        stop()
    }
}
