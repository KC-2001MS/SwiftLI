//
//  LifecycleModifier.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2024/05/27.
//

import Foundation

// MARK: - Lifecycle identity

/// Identifies a lifecycle modifier (`onAppear`, `task`) by its call site.
///
/// Views are value types recreated on every body evaluation, so an instance
/// cannot carry "already fired" state across renders. The call site — file,
/// line, column — is stable across re-evaluations of the same `body`, which
/// makes it the identity that "once per session" is tracked against.
struct LifecycleKey: Hashable, Sendable {
    let fileID: String
    let line: Int
    let column: Int
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
    /// One token per task that has started but not yet returned. The idle
    /// check consults this: a session with work in flight is never torn down.
    private var runningTaskTokens = Set<UUID>()
    /// The number of active self-redraw drivers (``CLITimer``s). While one is
    /// running the display can still change, so the session stays alive.
    private var activeDrivers = 0

    private init() {}

    /// Runs `action` the first time `key` is seen in the current session.
    func performOnce(key: LifecycleKey, action: () -> Void) {
        lock.lock()
        let isFirst = appeared.insert(key).inserted
        lock.unlock()
        if isFirst { action() }
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
        runningTaskTokens = []
        lock.unlock()
        for entry in running.values {
            entry.task.cancel()
        }
    }
}

// MARK: - onAppear

/// A view wrapper that executes an action the first time it is rendered.
///
/// `OnAppearView` is created by the `onAppear(perform:)` modifier and should
/// not normally be instantiated directly.
///
/// The action is called exactly once per rendering session — on the first
/// render pass that includes this view — even though `body` is re-evaluated
/// (and this wrapper recreated) on every state change. This is useful for
/// starting timers, kicking off animations, or scheduling any work that
/// should happen only when the view becomes visible.
///
/// ```swift
/// Group {
///     Text("Loading...").newLine()
/// }
/// .onAppear {
///     myTimer.start { progress += 0.1 }
/// }
/// ```
public struct OnAppearView: View {
    private let content: [any View]
    private let action: () -> Void
    private let key: LifecycleKey

    init(content: [any View], action: @escaping () -> Void, key: LifecycleKey) {
        self.content = content
        self.action = action
        self.key = key
    }

    /// The nominal view body; not used by the runtime because `makeNode()` is overridden.
    public var body: some View {
        // makeNode() is overridden, so body is not used by the runtime.
        EmptyView()
    }

    /// Lowers the wrapped content, firing the appear action exactly once per
    /// session.
    ///
    /// `makeNode()` is the single point every render pass funnels through, so
    /// firing here (guarded by ``SessionLifecycle``) reliably runs the action
    /// the first time the view is drawn.
    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        SessionLifecycle.shared.performOnce(key: key, action: action)
        return .group(children: content.map { $0.makeNode() })
    }
}

// MARK: - task

/// A view wrapper that starts an async task when the view first appears and
/// cancels it when the rendering session ends.
///
/// `TaskView` is created by the ``View/task(priority:fileID:line:column:_:)``
/// modifier and should not normally be instantiated directly.
public struct TaskView: View, @unchecked Sendable {
    private let content: [any View]
    private let key: LifecycleKey
    private let id: AnyHashable?
    private let priority: TaskPriority
    private let action: @Sendable () async -> Void

    init(
        content: [any View],
        key: LifecycleKey,
        id: AnyHashable?,
        priority: TaskPriority,
        action: @escaping @Sendable () async -> Void
    ) {
        self.content = content
        self.key = key
        self.id = id
        self.priority = priority
        self.action = action
    }

    /// The nominal view body; not used by the runtime because `makeNode()` is overridden.
    public var body: some View {
        // makeNode() is overridden, so body is not used by the runtime.
        EmptyView()
    }

    /// Lowers the wrapped content, starting the task on the first render pass
    /// of a reactive session that includes this view.
    ///
    /// Outside a reactive session (a one-shot `render()`), no task is started:
    /// nothing would keep the process alive to await it, and nothing would
    /// ever cancel it.
    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        if BodyRenderingStore.shared.sessionActive || AppRuntime.shared != nil {
            SessionLifecycle.shared.startTask(key: key, id: id, priority: priority, action: action)
        }
        return .group(children: content.map { $0.makeNode() })
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
    ) -> OnAppearView {
        OnAppearView(
            content: [self],
            action: action,
            key: LifecycleKey(fileID: fileID, line: line, column: column)
        )
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
    ) -> TaskView {
        TaskView(
            content: [self],
            key: LifecycleKey(fileID: fileID, line: line, column: column),
            id: nil,
            priority: priority,
            action: action
        )
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
    ) -> TaskView {
        TaskView(
            content: [self],
            key: LifecycleKey(fileID: fileID, line: line, column: column),
            id: AnyHashable(id),
            priority: priority,
            action: action
        )
    }
}
