//
//  LifecycleModifier.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2024/05/27.
//

import Foundation

// MARK: - Lifecycle identity

/// Identifies a lifecycle modifier (`onAppear`, `task`, `onChange`) by its
/// call site and the structural identity of the view it modifies.
///
/// Views are value types recreated on every body evaluation, so an instance
/// cannot carry "already fired" state across renders. The call site — file,
/// line, column — is stable across re-evaluations of the same `body`; the
/// view's identity (see ``RetainedTree``) tells the same call site apart
/// when it runs once per element of a `ForEach`, so every row gets its own
/// `task`, exactly as in SwiftUI. Outside a session that retains identities
/// the identity is the root's, and the call site alone decides.
struct LifecycleKey: Hashable, Sendable {
    let fileID: String
    let line: Int
    let column: Int
    var identity: UInt64 = RetainedTree.rootIdentity

    /// The key for the view being lowered right now.
    var located: LifecycleKey {
        var key = self
        key.identity = RenderPassContext.current?.identity ?? RetainedTree.rootIdentity
        return key
    }
}

// MARK: - Session lifecycle registry

/// Tracks which lifecycle actions have fired and which `task` modifiers are
/// running during the current rendering session.
///
/// Reset at every session boundary (``InlineCommand``/``FullScreenCommand``
/// start and stop, ``AppRuntime`` start and stop): outstanding tasks are
/// cancelled and the once-per-session state is cleared so the next session
/// fires everything afresh.
final class SessionLifecycle: @unchecked Sendable {
    static let shared = SessionLifecycle()

    private let lock = NSLock()
    private var appeared = Set<LifecycleKey>()
    private var tasks: [LifecycleKey: (id: AnyHashable?, task: Task<Void, Never>)] = [:]
    /// The `onDisappear` actions of the views in the most recent frame.
    private var disappearActions: [LifecycleKey: @Sendable () -> Void] = [:]
    /// The last value each `onChange` modifier observed.
    private var changeValues: [LifecycleKey: Any] = [:]
    /// The lifecycle keys lowered by the render pass in progress (`nil`
    /// outside a pass). At the end of the pass, a `task` whose key was not
    /// seen belongs to a view that left the tree: it is cancelled, its
    /// `onAppear` is re-armed, and its `onDisappear` runs.
    private var seenThisPass: Set<LifecycleKey>?
    /// One token per task that has started but not yet returned. The idle
    /// check consults this: a session with work in flight is never torn down.
    private var runningTaskTokens = Set<UUID>()
    /// The number of active self-redraw drivers (``CLITimer``s). While one is
    /// running the display can still change, so the session stays alive.
    private var activeDrivers = 0

    private init() {}

    /// Runs `action` the first time `key` is seen since the view appeared.
    func performOnce(key: LifecycleKey, action: () -> Void) {
        lock.lock()
        seenThisPass?.insert(key)
        let isFirst = appeared.insert(key).inserted
        lock.unlock()
        if isFirst { action() }
    }

    /// Registers the `onDisappear` action of a view in the current frame.
    func registerDisappear(key: LifecycleKey, action: @escaping @Sendable () -> Void) {
        lock.lock()
        seenThisPass?.insert(key)
        appeared.insert(key)
        disappearActions[key] = action
        lock.unlock()
    }

    /// Compares `value` with the one `key` observed last frame, running
    /// `action(old, new)` when it changed — or, with `initial`, once when the
    /// value is first seen. The action runs after the pass, on the main
    /// queue, so a state write inside it schedules the next frame instead of
    /// re-entering the one being drawn.
    func observeChange<V: Equatable & Sendable>(key: LifecycleKey, value: V, initial: Bool, action: @escaping @Sendable (V, V) -> Void) {
        lock.lock()
        seenThisPass?.insert(key)
        let previous = changeValues[key] as? V
        let seenBefore = changeValues[key] != nil
        changeValues[key] = value
        lock.unlock()
        if !seenBefore {
            if initial { DispatchQueue.main.async { action(value, value) } }
        } else if let previous, previous != value {
            DispatchQueue.main.async { action(previous, value) }
        }
    }

    // MARK: Render-pass bracketing

    /// Starts collecting the lifecycle keys of a frame.
    func beginPass() {
        lock.lock()
        seenThisPass = []
        lock.unlock()
    }

    /// Ends a frame: lifecycle state of views that are no longer in the tree
    /// is released — their tasks cancelled, their `onAppear` re-armed, their
    /// `onDisappear` run — so a view that comes back later starts afresh.
    func endPass() {
        lock.lock()
        guard let seen = seenThisPass else { lock.unlock(); return }
        seenThisPass = nil
        var cancelled: [Task<Void, Never>] = []
        for (key, entry) in tasks where !seen.contains(key) {
            cancelled.append(entry.task)
            tasks[key] = nil
        }
        var disappeared: [@Sendable () -> Void] = []
        for key in appeared where !seen.contains(key) {
            appeared.remove(key)
            if let action = disappearActions.removeValue(forKey: key) { disappeared.append(action) }
        }
        for key in changeValues.keys where !seen.contains(key) { changeValues[key] = nil }
        lock.unlock()
        for task in cancelled { task.cancel() }
        for action in disappeared { DispatchQueue.main.async { action() } }
    }

    /// Starts an async task for `key` unless one with the same `id` is
    /// already running. A different `id` cancels the previous task and starts
    /// a new one — the semantics of SwiftUI's `task(id:)`.
    func startTask(
        key: LifecycleKey,
        id: AnyHashable?,
        priority: TaskPriority,
        action: @escaping @Sendable () async -> Void
    ) {
        lock.lock()
        seenThisPass?.insert(key)
        if let existing = tasks[key] {
            if existing.id == id {
                lock.unlock()
                return
            }
            existing.task.cancel()
        }
        let token = UUID()
        runningTaskTokens.insert(token)
        tasks[key] = (id, Task(priority: priority) {
            await action()
            SessionLifecycle.shared.taskDidFinish(token)
        })
        lock.unlock()
    }

    /// Whether any `task` modifier's work is still in flight.
    var hasRunningTasks: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !runningTaskTokens.isEmpty
    }

    private func taskDidFinish(_ token: UUID) {
        lock.lock()
        runningTaskTokens.remove(token)
        lock.unlock()
    }

    /// Records that a self-redraw driver (a ``CLITimer``) started.
    func driverBegan() {
        lock.lock()
        activeDrivers += 1
        lock.unlock()
    }

    /// Records that a self-redraw driver stopped.
    func driverEnded() {
        lock.lock()
        activeDrivers = Swift.max(0, activeDrivers - 1)
        lock.unlock()
    }

    /// Whether any self-redraw driver is running.
    var hasActiveDrivers: Bool {
        lock.lock()
        defer { lock.unlock() }
        return activeDrivers > 0
    }

    /// Cancels every running task and clears the once-per-session state.
    ///
    /// Driver counts are left alone: they are balanced by ``CLITimer``'s own
    /// `start()`/`stop()`, which outlive any single session.
    func reset() {
        lock.lock()
        let running = tasks
        tasks = [:]
        appeared = []
        disappearActions = [:]
        changeValues = [:]
        seenThisPass = nil
        runningTaskTokens = []
        lock.unlock()
        for entry in running.values {
            entry.task.cancel()
        }
    }
}

// MARK: - onAppear

/// The modifier behind ``View/onAppear(fileID:line:column:perform:)``.
///
/// The action fires exactly once per rendering session — on the first
/// render pass that includes the content — even though `body` is
/// re-evaluated (and the modifier recreated) on every state change. This is
/// useful for starting timers, kicking off animations, or scheduling any
/// work that should happen only when the view becomes visible.
struct OnAppearModifier: ViewModifier {
    let action: () -> Void
    let key: LifecycleKey

    func node(for content: RenderNode) -> RenderNode {
        content
    }

    /// Lowering is the single point every render pass funnels through, so
    /// firing here (guarded by ``SessionLifecycle``) reliably runs the action
    /// the first time the view is drawn.
    func node(lowering content: () -> RenderNode) -> RenderNode {
        SessionLifecycle.shared.performOnce(key: key.located, action: action)
        return content()
    }
}

// MARK: - task

/// The modifier behind ``View/task(priority:fileID:line:column:_:)``: starts
/// an async task on the first render pass of a reactive session that
/// includes the content, and cancels it when the session ends.
struct TaskModifier: ViewModifier {
    let key: LifecycleKey
    let id: AnyHashable?
    let priority: TaskPriority
    let action: @Sendable () async -> Void

    func node(for content: RenderNode) -> RenderNode {
        content
    }

    /// Outside a reactive session (a one-shot `render()`), no task is started:
    /// nothing would keep the process alive to await it, and nothing would
    /// ever cancel it.
    func node(lowering content: () -> RenderNode) -> RenderNode {
        if BodyRenderingStore.shared.sessionActive || AppRuntime.shared != nil {
            SessionLifecycle.shared.startTask(key: key.located, id: id, priority: priority, action: action)
        }
        return content()
    }
}

// MARK: - onDisappear

/// The modifier behind ``View/onDisappear(fileID:line:column:perform:)``:
/// registers an action that ``SessionLifecycle`` runs once a frame no
/// longer contains the content.
struct OnDisappearModifier: ViewModifier {
    let action: @Sendable () -> Void
    let key: LifecycleKey

    func node(for content: RenderNode) -> RenderNode {
        content
    }

    func node(lowering content: () -> RenderNode) -> RenderNode {
        SessionLifecycle.shared.registerDisappear(key: key.located, action: action)
        return content()
    }
}

// MARK: - onChange

/// The modifier behind ``View/onChange(of:initial:fileID:line:column:_:)``:
/// hands the current value to ``SessionLifecycle`` every frame, which runs
/// the action (after the frame, on the main queue) when it changed.
struct OnChangeModifier<V: Equatable & Sendable>: ViewModifier {
    let value: V
    let initial: Bool
    let action: @Sendable (V, V) -> Void
    let key: LifecycleKey

    func node(for content: RenderNode) -> RenderNode {
        content
    }

    func node(lowering content: () -> RenderNode) -> RenderNode {
        SessionLifecycle.shared.observeChange(key: key.located, value: value, initial: initial, action: action)
        return content()
    }
}

// MARK: - View Extension

public extension View {
    /// Adds an action to perform when this view first appears on screen.
    ///
    /// The action fires exactly once per rendering session — on the first
    /// render pass that includes this view — even though state changes
    /// re-evaluate `body` and recreate the modifier.
    ///
    /// - Parameter action: The closure to execute when the view first appears.
    /// - Returns: A modified view that calls `action` before its first render.
    func onAppear(
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        perform action: @escaping () -> Void
    ) -> some View {
        modifier(OnAppearModifier(action: action, key: LifecycleKey(fileID: fileID, line: line, column: column)))
    }

    /// Adds an action to perform when this view leaves the tree, mirroring
    /// SwiftUI's `onDisappear(perform:)`.
    ///
    /// The view leaves the tree when a frame no longer contains it — a
    /// branch of an `if` switched, a `ForEach` row removed, a pushed
    /// destination popped. The action runs after that frame, on the main
    /// queue.
    func onDisappear(
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        perform action: @escaping @Sendable () -> Void
    ) -> some View {
        modifier(OnDisappearModifier(action: action, key: LifecycleKey(fileID: fileID, line: line, column: column)))
    }

    /// Runs an action when `value` changes, mirroring SwiftUI's
    /// `onChange(of:initial:_:)`.
    ///
    /// The value is compared between consecutive frames of a rendering
    /// session; when it differs the action receives the old and the new
    /// value. With `initial: true` the action also runs once with the first
    /// value seen. The action runs after the frame, on the main queue, so it
    /// may freely write `@State`.
    ///
    /// ```swift
    /// List(items, selection: $selection) { Text($0.title) }
    ///     .onChange(of: selection) { _, newValue in
    ///         model.preview(newValue)
    ///     }
    /// ```
    func onChange<V: Equatable & Sendable>(
        of value: V,
        initial: Bool = false,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        _ action: @escaping @Sendable (V, V) -> Void
    ) -> some View {
        modifier(OnChangeModifier(
            value: value,
            initial: initial,
            action: action,
            key: LifecycleKey(fileID: fileID, line: line, column: column)
        ))
    }

    /// Runs an action when `value` changes, mirroring SwiftUI's
    /// zero-parameter `onChange(of:initial:_:)`.
    func onChange<V: Equatable & Sendable>(
        of value: V,
        initial: Bool = false,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        _ action: @escaping @Sendable () -> Void
    ) -> some View {
        modifier(OnChangeModifier(
            value: value,
            initial: initial,
            action: { _, _ in action() },
            key: LifecycleKey(fileID: fileID, line: line, column: column)
        ))
    }

    /// Starts an async task when this view first appears in a rendering
    /// session, and cancels it when the session ends.
    ///
    /// Together with ``FullScreenCommand``'s default `run()`, this lets a
    /// command start its processing declaratively — no `run()` needed:
    ///
    /// ```swift
    /// struct Download: FullScreenCommand {
    ///     let manager = DownloadManager()   // @Observable
    ///
    ///     var body: some Scene {
    ///         Gauge(value: manager.progress)
    ///             .task { await manager.download() }
    ///     }
    /// }
    /// ```
    ///
    /// The task starts once per session, on the first render pass that
    /// includes this view, and receives cooperative cancellation when the
    /// session tears down. Outside a reactive session (one-shot `render()`),
    /// no task is started.
    ///
    /// - Parameters:
    ///   - priority: The priority of the created task.
    ///   - action: The async work to run.
    func task(
        priority: TaskPriority = .userInitiated,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        _ action: @escaping @Sendable () async -> Void
    ) -> some View {
        modifier(TaskModifier(key: LifecycleKey(fileID: fileID, line: line, column: column), id: nil, priority: priority, action: action))
    }

    /// Starts an async task tied to `id`: when the view reappears with a
    /// different `id`, the previous task is cancelled and a new one starts —
    /// the semantics of SwiftUI's `task(id:)`.
    ///
    /// - Parameters:
    ///   - id: The value the task's lifetime is tied to.
    ///   - priority: The priority of the created task.
    ///   - action: The async work to run.
    func task<ID: Hashable & Sendable>(
        id: ID,
        priority: TaskPriority = .userInitiated,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        _ action: @escaping @Sendable () async -> Void
    ) -> some View {
        modifier(TaskModifier(key: LifecycleKey(fileID: fileID, line: line, column: column), id: AnyHashable(id), priority: priority, action: action))
    }
}
