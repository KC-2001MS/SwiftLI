//
//  KeyInputRouter.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/07.
//

import Foundation

/// Bridges raw keyboard input to the focused ``TextField`` and the render loop.
///
/// The router owns the process's single ``KeyboardReader``. It is started
/// lazily — only once a ``TextField`` registers with ``FocusCoordinator`` — so
/// commands without any text input never switch the terminal into raw mode and
/// keep their normal Ctrl-C behaviour. Once started, every decoded
/// ``KeyEvent`` is:
///
/// - `.interrupt` (Ctrl-C): request the active runtime to exit.
/// - anything else: handed to ``FocusCoordinator`` (which edits the focused
///   field or moves focus), then a redraw is requested.
///
/// Redraws and exits are routed to **both** runtimes — the full-screen
/// ``CLIApp`` (`AppRuntime`) and any inline/full-screen ``InlineCommand``/``FullScreenCommand`` —
/// exactly like a `@State` mutation, so the router doesn't need to know which
/// one is active.
final class KeyInputRouter: @unchecked Sendable {
    static let shared = KeyInputRouter()

    private let lock = NSLock()
    private var reader: KeyboardReader?

    private init() {}

    /// Starts the keyboard reader if it isn't already running. Idempotent, and
    /// a no-op when stdin is not an interactive TTY (the reader handles that).
    func ensureStarted() {
        lock.lock()
        guard reader == nil else { lock.unlock(); return }
        // Mouse reporting is on for every interactive session. Full-screen
        // frames start at the terminal's first row, so a report's coordinates
        // address the frame directly; an inline frame sits wherever the
        // scrollback put it, so ``InlineRenderer`` follows each render with a
        // cursor-position query (CSI 6n) and the report below resolves the
        // frame's origin row.
        let r = KeyboardReader(enableMouse: true) { key in
            switch key {
            case .interrupt:
                AppRuntime.shared?.stop()
                BodyRenderingStore.shared.requestExit()
            case .mouse(let event):
                // Only redraw when something reacted — motion reports would
                // otherwise schedule render after render.
                if FocusCoordinator.shared.handleMouse(event) {
                    AppRuntime.shared?.scheduleRender()
                    StateObserverRegistry.shared.notifyChange()
                }
            case .cursorPosition(let row, _):
                // The answer to the inline renderer's origin query — pure
                // bookkeeping, never a reason to redraw.
                MouseTargetRegistry.shared.resolveInlineOrigin(parkedRow: row)
            default:
                _ = FocusCoordinator.shared.handle(key)
                // Redraw so focus/cursor moves show even without a text change.
                AppRuntime.shared?.scheduleRender()
                StateObserverRegistry.shared.notifyChange()
            }
        }
        reader = r
        lock.unlock()
        r.start()
    }

    /// Whether the terminal is currently reporting mouse events. The inline
    /// renderer checks this before emitting its cursor-position query, so a
    /// non-interactive render never writes escape queries into piped output.
    var isMouseTrackingActive: Bool {
        lock.lock(); defer { lock.unlock() }
        return reader?.isMouseTracking == true
    }

    /// Stops the reader and restores the terminal. Safe to call when never
    /// started. Called from every runtime's teardown.
    func stop() {
        lock.lock()
        let r = reader
        reader = nil
        lock.unlock()
        r?.stop()
        FocusCoordinator.shared.reset()
    }
}
