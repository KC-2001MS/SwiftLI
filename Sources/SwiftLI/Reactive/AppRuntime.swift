//
//  AppRuntime.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2024/05/27.
//

import Foundation

/// The runtime that manages the render loop for a reactive ``CLIApp``.
///
/// `AppRuntime` is the heart of SwiftLI's reactive system. It:
/// - Maintains a reference to the root ``CLIApp`` instance.
/// - Receives change notifications from ``State`` property wrappers.
/// - Coalesces rapid state changes into a single render pass (up to ~60 fps).
/// - Runs a `RunLoop` to keep the process alive while the app is active.
/// - Handles `SIGINT` (Ctrl+C) for clean shutdown.
/// - Handles `SIGWINCH` (terminal resize) by scheduling a re-render.
///
/// You do not create or interact with `AppRuntime` directly. It is created and
/// managed by ``CLIApp``'s `static func main()`.
public final class AppRuntime: @unchecked Sendable {

    // MARK: - Shared Instance

    /// The currently active runtime, set by ``run()`` and cleared on exit.
    ///
    /// ``State``'s setter uses this reference to schedule re-renders. Only one
    /// `AppRuntime` may be active at a time (one process, one app).
    nonisolated(unsafe) public private(set) static var shared: AppRuntime?

    // MARK: - Properties

    private let renderer = TerminalRenderer()
    private let app: any CLIApp
    private var isRunning = false

    /// Lock protecting `renderScheduled` and the render coalescing logic.
    private let renderLock = NSLock()
    /// `true` when a render has been enqueued but not yet executed.
    private var renderScheduled = false

    /// Minimum wall-clock time between renders (~60 fps).
    private let minRenderInterval: TimeInterval = 1.0 / 60.0

    /// Uptime timestamp of the most recent render.
    private var lastRenderTime: TimeInterval = 0

    // MARK: - Init

    init(app: any CLIApp) {
        self.app = app
    }

    // MARK: - Public Interface

    /// Starts the application.
    ///
    /// This method blocks until the app exits. It:
    /// 1. Sets `AppRuntime.shared` so `@State` can reach the runtime.
    /// 2. Sets up signal handlers.
    /// 3. Clears the screen and performs the first render.
    /// 4. Runs the main `RunLoop` until `stop()` is called.
    /// 5. Tears down the terminal.
    public func run() {
        AppRuntime.shared = self
        isRunning = true

        setupSignalHandlers()
        renderer.setup()
        performRender()

        let runLoop = RunLoop.current
        while isRunning {
            // 100ms timeout keeps the loop responsive to signal-driven stops
            runLoop.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
        }

        KeyInputRouter.shared.stop()
        renderer.teardown()
        AppRuntime.shared = nil
    }

    /// Schedules a re-render, coalescing multiple rapid changes into one pass.
    ///
    /// Called by ``State``'s property setter whenever a value changes.
    /// Thread-safe.
    public func scheduleRender() {
        renderLock.lock()
        guard !renderScheduled else {
            renderLock.unlock()
            return
        }
        renderScheduled = true
        renderLock.unlock()

        // Dispatch to main so renders are serialized with timer callbacks.
        DispatchQueue.main.async { [weak self] in
            self?.coalescedRender()
        }
    }

    /// Stops the application run loop gracefully.
    public func stop() {
        isRunning = false
    }

    // MARK: - Private Helpers

    /// Executes a render, or schedules it slightly in the future if the minimum
    /// interval has not elapsed since the last render.
    private func coalescedRender() {
        renderLock.lock()
        renderScheduled = false
        renderLock.unlock()

        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = now - lastRenderTime

        if elapsed < minRenderInterval {
            // Too soon — try again after the remaining interval.
            let delay = minRenderInterval - elapsed
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.performRender()
            }
        } else {
            performRender()
        }
    }

    /// Re-evaluates the app's `body` and renders the resulting view tree.
    private func performRender() {
        lastRenderTime = ProcessInfo.processInfo.systemUptime
        let views = app.body
        renderer.renderFullScreen(views)
    }

    /// Installs UNIX signal handlers for clean shutdown and resize handling.
    private func setupSignalHandlers() {
        // Ctrl+C: stop the run loop gracefully
        signal(SIGINT) { _ in
            AppRuntime.shared?.stop()
        }
        // Terminal resize: re-render at new dimensions
        signal(SIGWINCH) { _ in
            AppRuntime.shared?.scheduleRender()
        }
    }
}
