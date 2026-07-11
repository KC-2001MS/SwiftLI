//
//  Command.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2024/05/27.
//

import Foundation
import ArgumentParser

// MARK: - Command

/// The entry-point protocol for an argument-parsed SwiftLI command —
/// SwiftUI's `App` analog.
///
/// A command is not a ``View``: it *presents* one. Its `body` is a ``Scene``,
/// and `var body: some Scene` is the canonical spelling. Because ``View``
/// refines `Scene`, the body simply returns a view — it becomes the scene's
/// whole content (declaring `some View` also compiles, for the same reason).
/// Property wrappers (`@State`, `@Environment`, …) work in a command exactly
/// as they do in a view.
///
/// `Command` refines `AsyncParsableCommand`, so a single conformance carries
/// argument parsing, and the concrete protocols supply the rendering mode and
/// the default async `run()`:
/// - ``InlineCommand`` renders at the cursor, in the scrollback.
/// - ``FullScreenCommand`` renders on the alternate screen.
///
/// To embed one command's interface inside another, embed its `body` (a
/// command itself is not a view):
///
/// ```swift
/// var body: some Scene {
///     Text("above")
///     StatusCommand().body   // the other command's content
/// }
/// ```
public protocol Command: AsyncParsableCommand {
    /// The type of scene representing the content of this command.
    associatedtype Body: Scene

    /// The content of the command's interface: any number of view statements
    /// (they combine into one scene), or exactly one scene expression — see
    /// ``SceneBuilder``.
    @SceneBuilder
    var body: Body { get }
}

// MARK: - Shared rendering implementation

extension Command {

    /// Draws the first frame, registers for `@State`-driven redraws, and starts
    /// following terminal resizes. `fullScreen` selects the renderer.
    ///
    /// `print()` calls made while the session runs are captured by
    /// ``SessionPrintCapture`` so they cannot corrupt the live display: they
    /// are buffered and replayed in order right after the session ends —
    /// below the finished body (inline) or on the restored screen
    /// (full-screen).
    func _startBodyRendering(fullScreen: Bool) {
        let store = BodyRenderingStore.shared
        // A command whose session primitives run while another command's
        // session is already active joins that session instead of opening its
        // own: it inherits the parent's rendering mode — inline stays inline,
        // full-screen stays full-screen, never a switch — and the parent
        // keeps ownership of the renderer.
        guard store.beginSession(fullScreen: fullScreen) else { return }
        store.resetExit()
        // Start with clean lifecycle state so this session's `onAppear`/`task`
        // modifiers fire even if an earlier render already saw their call sites.
        SessionLifecycle.shared.reset()
        SessionPrintCapture.shared.start { line in
            BodyRenderingStore.shared.appendCapturedLog(line)
        }

        // Every render pass runs inside `RenderObservation.track` so that, in
        // addition to `@State`, properties of `@Observable` models read
        // anywhere in the pass — the body, modifiers, styles, `@Environment`
        // values, `Binding` getters evaluated during layout — re-trigger
        // these observer callbacks when they change.
        if fullScreen {
            let renderer = store.fullScreen
            renderer.beginAlternateScreen()
            RenderObservation.shared.track { renderer.renderFullScreen([self.body._sceneRoot()]) }
            StateObserverRegistry.shared.register {
                RenderObservation.shared.track { renderer.renderFullScreen([self.body._sceneRoot()]) }
            }
        } else {
            let renderer = store.inline
            RenderObservation.shared.track { renderer.render(self.body._sceneRoot()) }
            StateObserverRegistry.shared.register {
                // A fresh snapshot of `body` is read each time. Because `self`
                // is a struct captured by value and `body` reads the
                // reference-type StateStorage directly, it always reflects the
                // latest value.
                RenderObservation.shared.track { renderer.render(self.body._sceneRoot()) }
            }
        }

        // Redraw on terminal resize so width-relative views (a full-width
        // ``Divider``, an auto-sized ``ProgressView``) follow the new size. The
        // handler captures nothing, so it converts to a C function pointer; it
        // hops to the main queue before touching stdout.
        signal(SIGWINCH) { _ in
            DispatchQueue.main.async {
                StateObserverRegistry.shared.notifyChange()
            }
        }
    }

    /// Redraws `body` once, using whichever renderer the session started with.
    func _updateBody() {
        let store = BodyRenderingStore.shared
        if store.fullScreenActive {
            RenderObservation.shared.track { store.fullScreen.renderFullScreen([body._sceneRoot()]) }
        } else {
            RenderObservation.shared.track { store.inline.render(body._sceneRoot()) }
        }
    }

    /// Tears down observers, the keyboard reader, and the active renderer.
    func _stopBodyRendering() {
        // A nested command's stop leaves the enclosing session running; only
        // the owner that opened the session tears the renderer down.
        guard BodyRenderingStore.shared.endSession() else { return }
        signal(SIGWINCH, SIG_DFL)
        KeyInputRouter.shared.stop()
        StateObserverRegistry.shared.unregister()
        // Disarm observation-tracking handlers from this session so a late
        // model mutation cannot notify a renderer that has been torn down.
        RenderObservation.shared.invalidate()
        // Cancel `task` modifiers and clear once-per-session lifecycle state.
        SessionLifecycle.shared.reset()
        // Stop capturing before the renderer winds down, so even the very
        // last prints reach the log buffer. Later prints go straight to the
        // terminal.
        SessionPrintCapture.shared.stop()
        let store = BodyRenderingStore.shared
        if store.fullScreenActive {
            store.fullScreen.endAlternateScreen()
        } else {
            store.inline.finalize()
        }
        // Replay everything printed during the session, in order: below the
        // finished body (inline) or onto the restored screen (full-screen),
        // where it stays in the scrollback.
        let log = store.drainCapturedLog()
        if !log.isEmpty { TerminalOutput.write(log.joined()) }
        store.fullScreenActive = false
        store.sessionActive = false
    }

    /// Suspends until the user requests to quit (Ctrl-C in an interactive
    /// session sets the flag). Poll-based, so it works from any `run()`.
    func _waitUntilInterrupted() async {
        while !BodyRenderingStore.shared.exitRequested {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    /// `true` when nothing remains that could ever change the display: no
    /// `task` still running, no interactive control in the current frame, no
    /// redraw driver (``CLITimer``/``TimelineView``), and no change
    /// notification still in flight.
    var _sessionIsIdle: Bool {
        !SessionLifecycle.shared.hasRunningTasks
            && !FocusCoordinator.shared.hasVisibleControls
            && !SessionLifecycle.shared.hasActiveDrivers
            && !TimelineCoordinator.shared.hasArmedTimers
            && !RenderObservation.shared.hasPendingNotifications
    }

    /// Suspends until the session has nothing left to do (see
    /// ``_sessionIsIdle``) or the user interrupts / a view calls `dismiss()`.
    ///
    /// Idleness must hold for two consecutive polls: momentary gaps — a
    /// timeline timer between firing and re-arming, a task chaining into the
    /// next one via a state change — never end the session.
    func _waitUntilIdleOrInterrupted() async {
        var idleStreak = 0
        while !BodyRenderingStore.shared.exitRequested {
            if _sessionIsIdle {
                idleStreak += 1
                if idleStreak >= 2 { return }
            } else {
                idleStreak = 0
            }
            try? await Task.sleep(nanoseconds: 30_000_000)
        }
    }

    /// How long an idle full-screen body stays visible before its session
    /// ends by itself: the scene's ``Scene/readingPause(_:)`` override when
    /// set, else a reading pause proportional to the number of rows
    /// displayed, clamped to 2…10 seconds.
    var _readingPauseSeconds: Double {
        if let override = body._sceneConfiguration().readingPause {
            return override
        }
        let rows = NodeLayout.measure(body._sceneRoot().makeNode()).height
        return Swift.min(10.0, Swift.max(2.0, 1.0 + 0.2 * Double(rows)))
    }

    /// Suspends for the reading pause (see ``_readingPauseSeconds``), ending
    /// early when the user quits or a view calls `dismiss()`.
    func _lingerForReading() async {
        guard !BodyRenderingStore.shared.exitRequested else { return }
        let deadline = Date().addingTimeInterval(_readingPauseSeconds)
        while !BodyRenderingStore.shared.exitRequested && Date() < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    /// Runs a complete rendering session: draw, wait for Ctrl-C, tear down.
    func _runBody(fullScreen: Bool) async {
        _startBodyRendering(fullScreen: fullScreen)
        await _waitUntilInterrupted()
        _stopBodyRendering()
    }

    /// Runs a rendering session around `work`: draw, run the work, tear down.
    /// Teardown is deferred, so the terminal is restored even when `work`
    /// throws.
    func _runBody(fullScreen: Bool, while work: () async throws -> Void) async rethrows {
        _startBodyRendering(fullScreen: fullScreen)
        defer { _stopBodyRendering() }
        try await work()
    }
}

// MARK: - Inline commands

/// A ``Command`` whose content is rendered **inline** at the cursor.
///
/// `InlineCommand` (like ``FullScreenCommand``) refines ``Command``, so a
/// single conformance gives you argument parsing and rendering: declare a
/// `body` — any ``Scene``, and thus any ``View`` — and the async `run()` the
/// protocol provides drives the session. The content occupies only the rows
/// it needs, updates in place as `@State` changes, and remains in the
/// terminal scrollback after the command exits — the behaviour you want for
/// a progress bar or other small live display.
///
/// > Note: The session machinery is asynchronous, which is why the protocol
/// > refines `AsyncParsableCommand` rather than `ParsableCommand` — a
/// > synchronous `run() throws` could not await the session without blocking
/// > the redraw queue. A command that only needs one static frame doesn't
/// > need this protocol at all: call `render()` from any
/// > `ParsableCommand.run()`.
///
/// ## Usage
///
/// ```swift
/// import ArgumentParser
/// import SwiftLI
///
/// @main
/// struct Example: InlineCommand {
///     @State var value: Double = 0
///
///     mutating func run() async throws {
///         try await runBody {           // draws body; @State changes auto-redraw it
///             for _ in 0..<1000 {
///                 try await Task.sleep(nanoseconds: 100_000_000)
///                 value += 0.1         // triggers automatic body redraw
///             }
///         }
///     }
///
///     var body: some Scene {
///         ProgressView(min: 0, value: $value, max: 100)
///     }
/// }
/// ```
///
/// A command that just stays on screen until <kbd>Ctrl-C</kbd> is a single
/// call: `mutating func run() async throws { await runBody() }`. The
/// step-by-step primitives (``startBodyRendering()``,
/// ``waitUntilInterrupted()``, ``stopBodyRendering()``) remain available for
/// sessions with a custom shape.
///
/// ## Printing during the session
///
/// `print()` calls made between `startBodyRendering()` and
/// `stopBodyRendering()` are safe: the output is captured while the session
/// runs — so it cannot desync the in-place redraws — and replayed in order
/// just below the finished body the moment the session ends.
///
/// Switching to a full-screen app is just a matter of conforming to
/// ``FullScreenCommand`` instead — the `run()`/`body` code is identical.
///
/// ## Commands compose through their content
///
/// A command is not itself a view, but its `body` is: one command's `body`
/// can embed another command's content as `OtherCommand().body`. Only the
/// **root** command — the one whose `run()` started the session — decides
/// the rendering mode: a ``FullScreenCommand``'s content embedded in an
/// inline session renders inline, and vice versa.
///
/// The mode is inherited, never switched: even when a nested command's
/// session primitives (``startBodyRendering()``, ``runBody()``, `run()`) are
/// invoked while the parent's session is running, the call joins the parent's
/// session in the parent's mode — a nested ``FullScreenCommand`` cannot
/// pull an inline session onto the alternate screen, and its
/// ``stopBodyRendering()`` leaves the parent's session running.
public protocol InlineCommand: Command {}

public extension InlineCommand {
    /// Default entry point: runs a rendering session that ends by itself
    /// **when there is nothing left to do** — and leaves the final frame in
    /// the terminal scrollback.
    ///
    /// The session stays alive while anything could still change the display:
    /// - a `task` modifier's work is running,
    /// - an interactive control (``Button``, ``TextField``, ``Toggle``, …) is
    ///   on screen — the user still has something to do,
    /// - a redraw driver (``TimelineView``, ``CLITimer``) is active.
    ///
    /// When all of those are gone, the session ends. <kbd>Ctrl-C</kbd> and
    /// `@Environment(\.dismiss)` end it immediately at any point.
    ///
    /// A static body therefore prints once and exits; a progress bar lives
    /// exactly as long as its task; a prompt waits until its controls are
    /// hidden by a confirming action:
    ///
    /// ```swift
    /// struct Fetch: InlineCommand {
    ///     let model = FetchModel()   // @Observable
    ///
    ///     // Stored properties that aren't parsed from the command line
    ///     // (like `model`) don't have to be Decodable — list only the
    ///     // @Argument/@Option/@Flag properties here (none, in this case).
    ///     private enum CodingKeys: CodingKey {}
    ///
    ///     var body: some Scene {      // no run() required
    ///         ProgressView(min: 0, value: .constant(model.progress), max: 1)
    ///             .task { await model.fetch() }   // 完了 → やることゼロ → 終了
    ///     }
    /// }
    /// ```
    ///
    /// Implement `run()` yourself when the session needs a custom shape —
    /// work driving the session via ``runBody(while:)``, output printed after
    /// the session, or the step-by-step primitives.
    func run() async throws {
        _startBodyRendering(fullScreen: false)
        await _waitUntilIdleOrInterrupted()
        _stopBodyRendering()
    }

    /// Draws `body` inline and starts observing `@State` changes for automatic
    /// in-place redraws. Call once from `run()`.
    func startBodyRendering() { _startBodyRendering(fullScreen: false) }

    /// Forces an inline redraw without a `@State` change.
    func updateBody() { _updateBody() }

    /// Stops observing and parks the cursor just below the finished body so
    /// later `print()` output appears beneath it.
    func stopBodyRendering() { _stopBodyRendering() }

    /// Suspends until the user requests to quit (Ctrl-C in an interactive
    /// session). Use it to keep an interactive command alive while its
    /// controls collect input.
    func waitUntilInterrupted() async { await _waitUntilInterrupted() }

    /// Runs a complete rendering session: draws `body`, keeps it live until
    /// the user interrupts (<kbd>Ctrl-C</kbd>), then tears down.
    ///
    /// ```swift
    /// mutating func run() async throws {
    ///     await runBody()
    /// }
    /// ```
    func runBody() async { await _runBody(fullScreen: false) }

    /// Runs a rendering session while `work` executes: draws `body`, runs the
    /// work (with `@State` changes redrawing automatically), and tears down
    /// when it finishes. Teardown is deferred, so the terminal is restored
    /// even when the work throws.
    ///
    /// ```swift
    /// mutating func run() async throws {
    ///     try await runBody {
    ///         for i in 1...100 {
    ///             try await Task.sleep(nanoseconds: 30_000_000)
    ///             progress = Double(i) / 100
    ///         }
    ///     }
    /// }
    /// ```
    func runBody(while work: () async throws -> Void) async rethrows {
        try await _runBody(fullScreen: false, while: work)
    }
}

// MARK: - Full-screen commands

/// A ``Command`` whose content is rendered on the **alternate screen buffer**.
///
/// The body is repainted from the top-left every frame using the full terminal
/// width, exactly like `vim` or `htop`: it stays clean across window resizes,
/// and the original screen (and scrollback) is restored on
/// ``stopBodyRendering()`` — the behaviour you want for a full-screen app
/// (dashboards, menus). Any area the body does not cover is left blank.
///
/// ## Printing during the session
///
/// `print()` calls made between `startBodyRendering()` and
/// `stopBodyRendering()` are safe: the alternate screen has no scrollback, so
/// the output is captured while the session runs and replayed onto the normal
/// screen the moment the session ends — nothing is lost and the frame never
/// corrupts.
///
/// See ``InlineCommand`` for the shared usage pattern; the `run()`/`body` code
/// is identical between the two modes. Commands also compose through their
/// content: embed this command's `body` in another command's `body` and it
/// renders in whatever mode the **root** command chose — the parent's mode is
/// inherited, never switched, even if the nested command's session primitives
/// are invoked while the parent's session is running.
public protocol FullScreenCommand: Command {}

public extension FullScreenCommand {
    /// Default entry point: runs a complete rendering session — draw `body`,
    /// stay live while there is something to do, restore the screen.
    ///
    /// While anything could still change the display (an interactive control
    /// is on screen, a `task` is running, a redraw driver is active) the
    /// session stays live until the user quits (<kbd>Ctrl-C</kbd>) or a view
    /// calls `dismiss()` — so a command whose processing starts from the view
    /// itself doesn't need to write `run()` at all:
    ///
    /// ```swift
    /// struct Dashboard: FullScreenCommand {
    ///     var body: some View { ... }   // no run() required
    /// }
    /// ```
    ///
    /// A body with **nothing to do** — no controls, no task, no driver —
    /// doesn't vanish the moment it appears: the alternate screen stays up
    /// for a reading pause proportional to the amount displayed (2–10
    /// seconds), then the session ends by itself. <kbd>Ctrl-C</kbd> and
    /// `dismiss()` end it immediately at any point.
    ///
    /// Implement `run()` yourself when the session needs a custom shape —
    /// work driving the session via ``runBody(while:)``, output printed after
    /// the session, or the step-by-step primitives.
    func run() async throws {
        _startBodyRendering(fullScreen: true)
        await _waitUntilIdleOrInterrupted()
        // Nothing left to do: keep the screen readable for a moment before
        // restoring it (the pause scales with how much is displayed).
        await _lingerForReading()
        _stopBodyRendering()
    }

    /// Enters the alternate screen, draws `body`, and starts observing `@State`
    /// changes for automatic full-screen redraws. Call once from `run()`.
    func startBodyRendering() { _startBodyRendering(fullScreen: true) }

    /// Forces a full-screen redraw without a `@State` change.
    func updateBody() { _updateBody() }

    /// Stops observing and restores the screen that was visible before rendering.
    func stopBodyRendering() { _stopBodyRendering() }

    /// Suspends until the user requests to quit (Ctrl-C in an interactive
    /// session). See ``InlineCommand/waitUntilInterrupted()``.
    func waitUntilInterrupted() async { await _waitUntilInterrupted() }

    /// Runs a complete rendering session: draws `body`, keeps it live until
    /// the user interrupts (<kbd>Ctrl-C</kbd>), then restores the screen. See
    /// ``InlineCommand/runBody()``.
    func runBody() async { await _runBody(fullScreen: true) }

    /// Runs a rendering session while `work` executes, restoring the screen
    /// when it finishes (teardown is deferred, so the screen comes back even
    /// when the work throws). See ``InlineCommand/runBody(while:)``.
    func runBody(while work: () async throws -> Void) async rethrows {
        try await _runBody(fullScreen: true, while: work)
    }
}

// MARK: - Shared renderer store

/// Singleton store that holds the renderers for the current command and tracks
/// which rendering mode is active.
///
/// Using a store avoids adding stored properties to the protocol extension
/// (which Swift does not allow).
final class BodyRenderingStore: @unchecked Sendable {
    static let shared = BodyRenderingStore()

    let inline = InlineRenderer()
    let fullScreen = TerminalRenderer()

    private let lock = NSLock()
    private var _fullScreenActive = false
    private var _exitRequested = false
    private var _sessionActive = false
    // How many commands are currently inside the session: 1 for the owner
    // that opened it, +1 for every nested command whose session primitives
    // run while it is active.
    private var _sessionDepth = 0
    // `print()` output captured during a full-screen session, replayed onto
    // the normal screen once the alternate screen is left.
    private var _capturedLog: [String] = []

    var fullScreenActive: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _fullScreenActive }
        set { lock.lock(); _fullScreenActive = newValue; lock.unlock() }
    }

    /// Opens a rendering session, or joins the one already running.
    ///
    /// Returns `true` when this call opened the session — only that caller
    /// owns the renderer and may later tear it down. A nested call (a command
    /// whose session primitives run while another command's session is
    /// active) joins the existing session instead: the parent's rendering
    /// mode is kept — `fullScreen` is ignored — and `false` is returned.
    func beginSession(fullScreen: Bool) -> Bool {
        lock.lock(); defer { lock.unlock() }
        _sessionDepth += 1
        guard _sessionDepth == 1 else { return false }
        _fullScreenActive = fullScreen
        _sessionActive = true
        return true
    }

    /// Closes one level of session nesting. Returns `true` only when the
    /// outermost level closed — the owner should then tear the renderer down.
    func endSession() -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard _sessionDepth > 0 else { return false }
        _sessionDepth -= 1
        return _sessionDepth == 0
    }

    /// Whether a `startBodyRendering()` session is currently running. Views
    /// that are interactive only inside a reactive runtime (``Link``) check
    /// this so a one-shot `render()` keeps its plain, static output.
    var sessionActive: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _sessionActive }
        set { lock.lock(); _sessionActive = newValue; lock.unlock() }
    }

    /// Appends one captured `print()` line for replay after a full-screen
    /// session ends.
    func appendCapturedLog(_ line: String) {
        lock.lock(); _capturedLog.append(line); lock.unlock()
    }

    /// Returns and clears the captured `print()` lines.
    func drainCapturedLog() -> [String] {
        lock.lock(); defer { lock.unlock() }
        let log = _capturedLog
        _capturedLog = []
        return log
    }

    /// Set when the user asks to quit (Ctrl-C in an interactive session).
    var exitRequested: Bool {
        lock.lock(); defer { lock.unlock() }; return _exitRequested
    }

    /// Requests that an interactive `run()` loop stop (see
    /// ``InlineCommand/waitUntilInterrupted()``).
    func requestExit() {
        lock.lock(); _exitRequested = true; lock.unlock()
    }

    /// Clears the exit flag at the start of a new render session.
    func resetExit() {
        lock.lock(); _exitRequested = false; lock.unlock()
    }

    private init() {}
}
