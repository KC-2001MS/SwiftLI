//
//  KeyboardReader.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/07.
//

import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Restores the terminal's original settings on any process exit path.
///
/// ``KeyboardReader/stop()`` handles the normal teardown, but a session can
/// also end via `exit()` (which ArgumentParser calls), an uncaught error, or
/// a fatal signal — none of which run the teardown. If raw mode survives the
/// process, every later command in the same terminal prints staircased text
/// (`\n` without a carriage return, because `OPOST` is still off). This guard
/// saves the pre-raw termios and restores it from an `atexit` hook and
/// fatal-signal handlers.
private enum TerminalRestoreGuard {
    nonisolated(unsafe) private static var saved = termios()
    nonisolated(unsafe) private static var hasSaved = false
    nonisolated(unsafe) private static var installed = false

    /// Records the pre-raw settings and installs the exit hooks (once).
    static func arm(original: termios) {
        saved = original
        hasSaved = true
        guard !installed else { return }
        installed = true
        atexit { TerminalRestoreGuard.restore() }
        // Raw mode disables ISIG, so Ctrl-C never reaches these — but an
        // external SIGTERM/SIGHUP/SIGQUIT would otherwise kill the process
        // with the terminal still raw. Restore, then re-raise the default
        // action so the process still dies with the correct status.
        for sig in [SIGTERM, SIGHUP, SIGQUIT] {
            signal(sig) { s in
                TerminalRestoreGuard.restore()
                signal(s, SIG_DFL)
                raise(s)
            }
        }
    }

    /// Marks raw mode as exited normally; the hooks become no-ops.
    static func disarm() {
        hasSaved = false
    }

    /// Restores the saved settings. Async-signal-safe: no locks, no
    /// allocation — it may run inside a signal handler.
    static func restore() {
        guard hasSaved else { return }
        hasSaved = false
        tcsetattr(STDIN_FILENO, TCSANOW, &saved)
    }
}

/// Puts the terminal into raw mode and reads keystrokes on a background thread,
/// decoding them into ``KeyEvent`` values delivered on the main queue.
///
/// This is the input half of SwiftLI's reactive runtime. In raw mode the
/// terminal delivers each keystroke immediately (no line buffering, no echo),
/// which is what lets a ``TextField`` update character-by-character. The
/// original terminal settings are always restored on ``stop()``.
///
/// The reader only activates when stdin is an interactive TTY; when input is
/// piped or redirected it stays inert so non-interactive runs are unaffected.
final class KeyboardReader: @unchecked Sendable {

    private let onEvent: @Sendable (KeyEvent) -> Void
    private var originalTermios = termios()
    private var isActive = false
    private var running = false
    private var thread: Thread?

    /// Creates a reader that forwards each decoded event via `onEvent`.
    ///
    /// - Parameter onEvent: Invoked on the **main queue** for every key.
    init(onEvent: @escaping @Sendable (KeyEvent) -> Void) {
        self.onEvent = onEvent
    }

    /// Enables raw mode and starts the background read loop.
    ///
    /// Does nothing when stdin is not a TTY.
    func start() {
        guard isatty(STDIN_FILENO) == 1 else { return }

        // Save and switch to raw mode (no echo, no canonical line editing,
        // no signal generation — Ctrl-C arrives as a byte we handle ourselves).
        tcgetattr(STDIN_FILENO, &originalTermios)
        var raw = originalTermios
        cfmakeraw(&raw)

        // Use a *timed* blocking read (VMIN=0, VTIME=1 → up to ~0.1s) so the loop
        // stays responsive to `stop()` WITHOUT marking the terminal file
        // description non-blocking. On a TTY, stdin and stdout share one open
        // file description, so setting O_NONBLOCK on stdin also makes stdout
        // writes non-blocking — which silently truncates a large frame repaint
        // (e.g. a full-viewport scroll diff) with a short write when the tty
        // buffer is momentarily full. A timed read avoids touching those flags.
        let ccCount = MemoryLayout.size(ofValue: raw.c_cc) / MemoryLayout<cc_t>.stride
        withUnsafeMutablePointer(to: &raw.c_cc) { tuple in
            tuple.withMemoryRebound(to: cc_t.self, capacity: ccCount) { cc in
                cc[Int(VMIN)] = 0
                cc[Int(VTIME)] = 1
            }
        }
        tcsetattr(STDIN_FILENO, TCSANOW, &raw)
        // Make sure the original settings come back even if the process exits
        // without reaching stop() — exit(), a crash, or a fatal signal.
        TerminalRestoreGuard.arm(original: originalTermios)

        isActive = true
        running = true
        let t = Thread { [weak self] in self?.loop() }
        t.stackSize = 1 << 20
        thread = t
        t.start()
    }

    /// Stops the read loop and restores the terminal's original settings.
    func stop() {
        guard isActive else { return }
        running = false
        tcsetattr(STDIN_FILENO, TCSANOW, &originalTermios)
        TerminalRestoreGuard.disarm()
        isActive = false
    }

    // MARK: - Read loop

    private func loop() {
        var decoder = KeyDecoder()
        let bufSize = 64
        var buf = [UInt8](repeating: 0, count: bufSize)

        while running {
            let n = read(STDIN_FILENO, &buf, bufSize)
            if n > 0 {
                let events = decoder.feed(Array(buf[0..<n]))
                for event in events {
                    let cb = onEvent
                    DispatchQueue.main.async { cb(event) }
                }
            } else if n < 0 {
                // Read error; yield briefly and retry.
                usleep(5000)
            }
            // n == 0: the timed read returned no data (VTIME elapsed). Loop back
            // to re-check `running` so stop() is noticed promptly.
        }
    }
}
