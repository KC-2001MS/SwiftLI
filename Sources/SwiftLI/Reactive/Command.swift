//
//  Command.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2024/05/27.
//

import Foundation

// MARK: - Shared rendering implementation

extension View {

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
        store.fullScreenActive = fullScreen
        store.sessionActive = true
        store.resetExit()
        SessionPrintCapture.shared.start { line in
            BodyRenderingStore.shared.appendCapturedLog(line)
        }

        if fullScreen {
            let renderer = store.fullScreen
            renderer.beginAlternateScreen()
            renderer.renderFullScreen([body])
            StateObserverRegistry.shared.register {
                renderer.renderFullScreen([self.body])
            }
        } else {
            let renderer = store.inline
            renderer.render(body)
            StateObserverRegistry.shared.register {
                // A fresh snapshot of `body` is read each time. Because `self`
                // is a struct captured by value and `body` reads the
                // reference-type StateStorage directly, it always reflects the
                // latest value.
                renderer.render(self.body)
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
            store.fullScreen.renderFullScreen([body])
        } else {
            store.inline.render(body)
        }
    }

    /// Tears down observers, the keyboard reader, and the active renderer.
    func _stopBodyRendering() {
        signal(SIGWINCH, SIG_DFL)
        KeyInputRouter.shared.stop()
        StateObserverRegistry.shared.unregister()
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
}

// MARK: - Inline commands

/// A command whose ``View/body`` is rendered **inline** at the cursor.
///
/// A command is just a ``View`` with a rendering mode: conform your
/// `AsyncParsableCommand` to `InlineCommand` (or ``FullScreenCommand``) and
/// declare a `body`. The body occupies only the rows it needs, updates in
/// place as `@State` changes, and remains in the terminal scrollback after the
/// command exits — the behaviour you want for a progress bar or other small
/// live display.
///
/// ## Usage
///
/// ```swift
/// import ArgumentParser
/// import SwiftLI
///
/// @main
/// struct Example: AsyncParsableCommand, InlineCommand {
///     @State var value: Double = 0
///
///     mutating func run() async throws {
///         startBodyRendering()          // draws body; @State changes auto-redraw it
///         for _ in 0..<1000 {
///             try await Task.sleep(nanoseconds: 100_000_000)
///             value += 0.1             // triggers automatic body redraw
///         }
///         stopBodyRendering()
///     }
///
///     var body: some View {
///         ProgressView(min: 0, value: $value, max: 100)
///     }
/// }
/// ```
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
public protocol InlineCommand: View {}

public extension InlineCommand {
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
    /// controls collect input:
    ///
    /// ```swift
    /// mutating func run() async throws {
    ///     startBodyRendering()
    ///     await waitUntilInterrupted()
    ///     stopBodyRendering()
    /// }
    /// ```
    func waitUntilInterrupted() async { await _waitUntilInterrupted() }
}

// MARK: - Full-screen commands

/// A command whose ``View/body`` is rendered on the **alternate screen buffer**.
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
/// is identical between the two modes.
public protocol FullScreenCommand: View {}

public extension FullScreenCommand {
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
    // `print()` output captured during a full-screen session, replayed onto
    // the normal screen once the alternate screen is left.
    private var _capturedLog: [String] = []

    var fullScreenActive: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _fullScreenActive }
        set { lock.lock(); _fullScreenActive = newValue; lock.unlock() }
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
