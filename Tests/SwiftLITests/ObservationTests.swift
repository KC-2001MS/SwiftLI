//
//  ObservationTests.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/10.
//

import Foundation
import Testing
import Observation
@_spi(RenderingInternals) @testable import SwiftLI

@Observable
private final class CounterModel: @unchecked Sendable {
    var count = 0
}

/// An environment key carrying an observable model, as an app would use to
/// hand a model to descendant views via `.environment(...)`.
private struct CounterModelKey: EnvironmentKey {
    static var defaultValue: CounterModel? { nil }
}

/// Thread-safe invocation counter for observer callbacks.
private final class NotifyCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var _count = 0

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return _count
    }

    func increment() {
        lock.lock()
        _count += 1
        lock.unlock()
    }
}

/// Polls until `condition` is met or the timeout elapses.
private func waitUntil(timeout: TimeInterval = 1.0, _ condition: () -> Bool) async throws {
    let deadline = ProcessInfo.processInfo.systemUptime + timeout
    while !condition() && ProcessInfo.processInfo.systemUptime < deadline {
        try await Task.sleep(nanoseconds: 10_000_000)
    }
}

// Nested inside ControlSingletonTests so these tests never run in parallel
// with the session tests: both sides take the single StateObserverRegistry
// observer slot, and an idle-exit session whose observer was stolen would
// never see its re-render and hang.
extension ControlSingletonTests {
@Suite(.serialized)
struct ObservationTests {

    @Test func trackReturnsTheAppliedValue() {
        let model = CounterModel()
        model.count = 7
        let value = RenderObservation.shared.track { model.count * 6 }
        #expect(value == 42)
    }

    @Test func observableChangeNotifiesObserver() async throws {
        let model = CounterModel()
        let notifications = NotifyCounter()
        StateObserverRegistry.shared.register { notifications.increment() }
        defer { StateObserverRegistry.shared.unregister() }

        _ = RenderObservation.shared.track { model.count }
        model.count += 1

        try await waitUntil { notifications.count >= 1 }
        #expect(notifications.count >= 1)
    }

    @Test func staleTrackingDoesNotDuplicateNotifications() async throws {
        let model = CounterModel()
        let notifications = NotifyCounter()
        StateObserverRegistry.shared.register { notifications.increment() }
        defer { StateObserverRegistry.shared.unregister() }

        // Two tracked evaluations: only the most recent generation may fire.
        _ = RenderObservation.shared.track { model.count }
        _ = RenderObservation.shared.track { model.count }
        model.count += 1

        try await waitUntil { notifications.count >= 1 }
        // Give a superseded handler time to (incorrectly) fire before checking.
        try await Task.sleep(nanoseconds: 200_000_000)
        #expect(notifications.count == 1)
    }

    @Test func invalidateDisarmsTracking() async throws {
        let model = CounterModel()
        let notifications = NotifyCounter()
        StateObserverRegistry.shared.register { notifications.increment() }
        defer { StateObserverRegistry.shared.unregister() }

        _ = RenderObservation.shared.track { model.count }
        RenderObservation.shared.invalidate()
        model.count += 1

        try await Task.sleep(nanoseconds: 200_000_000)
        #expect(notifications.count == 0)
    }

    // MARK: - Bindable

    @Test func bindableDerivesWorkingBindings() {
        let model = CounterModel()
        let count: Binding<Int> = Bindable(model).count
        #expect(count.wrappedValue == 0)
        count.wrappedValue = 5
        #expect(model.count == 5)
    }

    @Test func bindableWriteNotifiesTrackedObserver() async throws {
        let model = CounterModel()
        let notifications = NotifyCounter()
        StateObserverRegistry.shared.register { notifications.increment() }
        defer { StateObserverRegistry.shared.unregister() }

        let count = Bindable(model).count
        // A control reads its binding during layout, not in a view body; the
        // render pass wraps layout too, so the read must still be tracked.
        _ = RenderObservation.shared.track { count.wrappedValue }
        count.wrappedValue += 1

        try await waitUntil { notifications.count >= 1 }
        #expect(notifications.count >= 1)
        #expect(model.count == 1)
    }

    // MARK: - Binding dynamic member lookup

    @Test func bindingDynamicMemberWritesBackThroughParent() {
        struct Form: Sendable {
            var name = ""
            var age = 0
        }
        let storage = StateStorage(value: Form())
        let form = Binding<Form>(
            get: { storage.value },
            set: { storage.value = $0 }
        )

        let name = form.name
        name.wrappedValue = "Keisuke"

        #expect(storage.value.name == "Keisuke")
        #expect(storage.value.age == 0)
        #expect(name.wrappedValue == "Keisuke")
    }

    @Test func nestedStateBindingWriteNotifiesObservers() {
        struct Form: Sendable {
            var name = ""
        }
        let state = State(wrappedValue: Form())
        let notifications = NotifyCounter()
        StateObserverRegistry.shared.register { notifications.increment() }
        defer { StateObserverRegistry.shared.unregister() }

        // `$form.name` handed to a child view: writing through the derived
        // binding must update the parent state and notify, like a direct set.
        state.projectedValue.name.wrappedValue = "abc"

        #expect(state.wrappedValue.name == "abc")
        #expect(notifications.count == 1)
    }

    // MARK: - @Environment

    @Test func typedEnvironmentObjectInjection() {
        let model = CounterModel()
        var values = EnvironmentValues()
        values[CounterModel.self] = model

        EnvironmentStack.with(values) {
            // Required form returns the injected instance…
            #expect(Environment(CounterModel.self).wrappedValue === model)
            // …and the optional form finds the same one.
            #expect(Environment(CounterModel?.self).wrappedValue === model)
        }
        // Outside the scope nothing is injected: the optional form is nil.
        #expect(Environment(CounterModel?.self).wrappedValue == nil)
    }

    @Test func environmentObjectFlowsThroughViewTreeAndIsTracked() async throws {
        let model = CounterModel()
        model.count = 5
        let notifications = NotifyCounter()
        StateObserverRegistry.shared.register { notifications.increment() }
        defer { StateObserverRegistry.shared.unregister() }

        struct Child: View {
            @Environment(CounterModel.self) private var model

            var body: some View {
                Text("count: \(model.count)")
            }
        }

        // `.environment(model)` injects by type; the child reads it back and
        // renders the current value.
        let tree = VStack { Child() }.environment(model)
        let out = RenderObservation.shared.track {
            TextMetrics.stripANSI(tree.renderString())
        }
        #expect(out.contains("count: 5"))

        // The tracked read means a later mutation notifies the render loop.
        model.count += 1
        try await waitUntil { notifications.count >= 1 }
        #expect(notifications.count >= 1)
    }

    @Test func environmentModelReadDuringRenderIsTracked() async throws {
        let model = CounterModel()
        let notifications = NotifyCounter()
        StateObserverRegistry.shared.register { notifications.increment() }
        defer { StateObserverRegistry.shared.unregister() }

        var values = EnvironmentValues()
        values[CounterModelKey.self] = model
        // A descendant reads the model out of the environment mid-render
        // (environment scopes only exist inside the render pass).
        _ = RenderObservation.shared.track {
            EnvironmentStack.with(values) {
                EnvironmentStack.current[CounterModelKey.self]?.count
            }
        }
        model.count += 1

        try await waitUntil { notifications.count >= 1 }
        #expect(notifications.count >= 1)
    }
}
}
