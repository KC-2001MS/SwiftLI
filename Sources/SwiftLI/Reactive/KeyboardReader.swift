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
