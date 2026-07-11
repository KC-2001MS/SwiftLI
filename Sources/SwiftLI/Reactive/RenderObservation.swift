//
//  RenderObservation.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/10.
//

import Foundation
import Observation

/// Bridges the standard `Observation` framework into SwiftLI's render loop.
///
/// Every render pass in the reactive runtimes (``AppRuntime`` and the
/// ``InlineCommand``/``FullScreenCommand`` sessions) is wrapped in
/// ``track(_:)`` — not just the `body` evaluation but also the `makeNode()`
/// lowering and layout it triggers, so reads made by view bodies, modifiers,
/// styles, `@Environment` values, and `Binding` getters are all covered. Any
/// property of an `@Observable` object read during the pass is registered
/// with `withObservationTracking`; when one of those properties later
/// changes, the same notifications used by ``State`` fire —
/// `AppRuntime.scheduleRender()` and `StateObserverRegistry.notifyChange()` —
/// which re-renders and thereby re-establishes tracking for the next change
/// (observation tracking is one-shot).
///
/// Only `withObservationTracking(_:onChange:)` is used, keeping the package's
/// macOS 14 deployment target; the newer tracking APIs require later OS
/// releases.
final class RenderObservation: @unchecked Sendable {
    static let shared = RenderObservation()

    private let lock = NSLock()
    /// Incremented on every tracked evaluation (and on ``invalidate()``).
    /// Each render leaves behind a one-shot `onChange` handler; handlers from
    /// superseded evaluations compare their generation against this value and
    /// do nothing, so a long session cannot accumulate stale handlers that
    /// each trigger an extra render on the next change.
    private var generation: UInt64 = 0
    /// The number of change notifications currently in flight on the main
    /// queue. The idle check consults this so a session is never torn down
    /// between an `@Observable` mutation and the re-render it schedules.
    private var pendingNotifications = 0

    private init() {}

    /// Evaluates `apply` while tracking access to `@Observable` properties,
    /// scheduling a re-render when any tracked property changes.
    func track<T>(_ apply: () -> T) -> T {
        lock.lock()
        generation &+= 1
        let current = generation
        lock.unlock()

        let handler: @Sendable () -> Void = { [weak self] in
            guard let self, self.isCurrent(current) else { return }
            AppRuntime.shared?.scheduleRender()
            // `onChange` fires at `willSet`, before the new value has landed.
            // `StateObserverRegistry` invokes its observer synchronously, so
            // hop to the main queue first — by the time the block runs the
            // mutation is complete and the redraw reads the new value.
            // (`scheduleRender()` above already dispatches internally.)
            self.notificationScheduled()
            DispatchQueue.main.async {
                StateObserverRegistry.shared.notifyChange()
                self.notificationDelivered()
            }
        }
        return withObservationTracking(apply, onChange: handler)
    }

    /// Whether a change notification is scheduled but not yet delivered.
    var hasPendingNotifications: Bool {
        lock.lock()
        defer { lock.unlock() }
        return pendingNotifications > 0
    }

    private func notificationScheduled() {
        lock.lock()
        pendingNotifications += 1
        lock.unlock()
    }

    private func notificationDelivered() {
        lock.lock()
        pendingNotifications -= 1
        lock.unlock()
    }

    /// Disarms all outstanding `onChange` handlers. Called when a rendering
    /// session ends so a late mutation of a previously tracked model cannot
    /// notify observers that no longer exist.
    func invalidate() {
        lock.lock()
        generation &+= 1
        lock.unlock()
    }

    private func isCurrent(_ generation: UInt64) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return generation == self.generation
    }
}
