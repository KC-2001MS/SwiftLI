//
//  ViewableCommand.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2024/05/27.
//

import Foundation

/// A protocol that adds a declarative ``View`` body to an `AsyncParsableCommand`.
///
/// `ViewableCommand` itself only supplies the ``body``. To render it, conform to
/// one of its two refinements, which pick the rendering mode:
///
/// - ``InlineViewableCommand`` — draws the body **inline** at the cursor and
///   updates it in place. The output stays in the scrollback after the command
///   exits. Best for small, transient displays such as a progress bar.
/// - ``FullScreenViewableCommand`` — draws the body on the **alternate screen
///   buffer** and repaints it from the top-left every frame, exactly like `vim`
///   or `htop`. It uses the full width, is immune to terminal reflow on resize,
///   and restores the original screen on exit. Best for full-screen apps
///   (dashboards, menus); the unused area is simply left blank.
///
/// ## Usage
///
/// ```swift
/// import ArgumentParser
/// import SwiftLI
///
/// @main
/// struct Example: AsyncParsableCommand, InlineViewableCommand {
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
/// Switching to a full-screen app is just a matter of conforming to
/// ``FullScreenViewableCommand`` instead — the `run()`/`body` code is identical.
public protocol ViewableCommand {
    associatedtype Body: View
    /// The view displayed alongside the command's output.
    var body: Body { get }
}

// MARK: - Shared rendering implementation

extension ViewableCommand {

    /// Draws the first frame, registers for `@State`-driven redraws, and starts
    /// following terminal resizes. `fullScreen` selects the renderer.
    func _startBodyRendering(fullScreen: Bool) {
        let store = BodyRenderingStore.shared
        store.fullScreenActive = fullScreen
        store.resetExit()

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
        let store = BodyRenderingStore.shared
        if store.fullScreenActive {
            store.fullScreen.endAlternateScreen()
        } else {
            store.inline.finalize()
        }
        store.fullScreenActive = false
    }

    /// Suspends until the user requests to quit (Ctrl-C in a ``TextField``
    /// session sets the flag). Poll-based, so it works from any `run()`.
    ///
    /// Use it to keep an interactive command alive while its fields collect
    /// input:
    ///
    /// ```swift
    /// mutating func run() async throws {
    ///     startBodyRendering()
    ///     await waitUntilInterrupted()
    ///     stopBodyRendering()
    /// }
    /// ```
    public func waitUntilInterrupted() async {
        while !BodyRenderingStore.shared.exitRequested {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }
}

// MARK: - Inline commands

/// A ``ViewableCommand`` rendered **inline** at the cursor.
///
/// The body occupies only the rows it needs, updates in place as `@State`
/// changes, and remains in the terminal scrollback after the command exits —
/// the behaviour you want for a progress bar or other small live display.
public protocol InlineViewableCommand: ViewableCommand {}

public extension InlineViewableCommand {
    /// Draws `body` inline and starts observing `@State` changes for automatic
    /// in-place redraws. Call once from `run()`.
    func startBodyRendering() { _startBodyRendering(fullScreen: false) }

    /// Forces an inline redraw without a `@State` change.
    func updateBody() { _updateBody() }

    /// Stops observing and parks the cursor just below the finished body so
    /// later `print()` output appears beneath it.
    func stopBodyRendering() { _stopBodyRendering() }
}

// MARK: - Full-screen commands

/// A ``ViewableCommand`` rendered on the **alternate screen buffer**.
///
/// The body is repainted from the top-left every frame using the full terminal
/// width, stays clean across window resizes, and the original screen (and
/// scrollback) is restored on ``stopBodyRendering()`` — the behaviour you want
/// for a full-screen app. Any area the body does not cover is left blank.
public protocol FullScreenViewableCommand: ViewableCommand {}

public extension FullScreenViewableCommand {
    /// Enters the alternate screen, draws `body`, and starts observing `@State`
    /// changes for automatic full-screen redraws. Call once from `run()`.
    func startBodyRendering() { _startBodyRendering(fullScreen: true) }

    /// Forces a full-screen redraw without a `@State` change.
    func updateBody() { _updateBody() }

    /// Stops observing and restores the screen that was visible before rendering.
    func stopBodyRendering() { _stopBodyRendering() }
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

    var fullScreenActive: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _fullScreenActive }
        set { lock.lock(); _fullScreenActive = newValue; lock.unlock() }
    }

    /// Set when the user asks to quit (Ctrl-C in an interactive field session).
    var exitRequested: Bool {
        lock.lock(); defer { lock.unlock() }; return _exitRequested
    }

    /// Requests that an interactive `run()` loop stop (see
    /// ``ViewableCommand/waitUntilInterrupted()``).
    func requestExit() {
        lock.lock(); _exitRequested = true; lock.unlock()
    }

    /// Clears the exit flag at the start of a new render session.
    func resetExit() {
        lock.lock(); _exitRequested = false; lock.unlock()
    }

    private init() {}
}
