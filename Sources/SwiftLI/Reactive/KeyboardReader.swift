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
#elseif os(Windows)
import WinSDK
#endif

// MARK: - TerminalRestoreGuard

#if os(Windows)
/// Restores Windows console mode on any process exit path.
///
/// Plays the same role as the Unix `termios`-based guard: ensures the console
/// is returned to its original mode even when the process exits via `exit()`,
/// a crash, or a fatal signal.
private enum TerminalRestoreGuard {
    nonisolated(unsafe) private static var savedMode: DWORD = 0
    nonisolated(unsafe) private static var hasSaved = false
    nonisolated(unsafe) private static var installed = false
    nonisolated(unsafe) private static var mouseEnabled = false
    private static let disableMouseBytes = Array(MouseReporting.disableSequence.utf8)

    static func arm(original: DWORD, mouseEnabled: Bool) {
        savedMode = original
        hasSaved = true
        self.mouseEnabled = mouseEnabled
        guard !installed else { return }
        installed = true
        atexit { TerminalRestoreGuard.restore() }
        signal(SIGTERM) { s in
            TerminalRestoreGuard.restore()
            signal(s, SIG_DFL)
            raise(s)
        }
    }

    static func disarm() { hasSaved = false }

    static func restore() {
        guard hasSaved else { return }
        hasSaved = false
        if mouseEnabled {
            mouseEnabled = false
            disableMouseBytes.withUnsafeBufferPointer { buf in
                guard let base = buf.baseAddress else { return }
                _ = _write(1, base, UInt32(buf.count))
            }
        }
        SetConsoleMode(GetStdHandle(STD_INPUT_HANDLE), savedMode)
    }
}
#else
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
    nonisolated(unsafe) private static var mouseEnabled = false
    /// The mouse-reporting disable sequence as raw bytes, precomputed so the
    /// signal-handler path never allocates.
    private static let disableMouseBytes = Array(MouseReporting.disableSequence.utf8)

    /// Records the pre-raw settings and installs the exit hooks (once).
    static func arm(original: termios, mouseEnabled: Bool) {
        saved = original
        hasSaved = true
        self.mouseEnabled = mouseEnabled
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
        if mouseEnabled {
            mouseEnabled = false
            // A surviving mouse-reporting mode would spray escape sequences
            // into the shell on every click; turn it off before the termios
            // restore, using raw write(2) so this stays signal-safe.
            disableMouseBytes.withUnsafeBufferPointer { buffer in
                _ = write(STDOUT_FILENO, buffer.baseAddress, buffer.count)
            }
        }
        tcsetattr(STDIN_FILENO, TCSANOW, &saved)
    }
}
#endif

/// The escape sequences that switch terminal mouse reporting on and off.
///
/// SwiftLI requests button presses/releases (`?1000`), button-motion (drag)
/// reports (`?1002`), and the SGR extended coordinate encoding (`?1006`) —
/// the combination every modern terminal supports and ``KeyDecoder`` parses.
enum MouseReporting {
    /// Enables press/release + drag reporting in SGR encoding.
    static let enableSequence = "\u{001B}[?1000h\u{001B}[?1002h\u{001B}[?1006h"
    /// Disables everything ``enableSequence`` enabled (reverse order).
    static let disableSequence = "\u{001B}[?1006l\u{001B}[?1002l\u{001B}[?1000l"
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
    /// Whether to switch the terminal's mouse reporting on for this session.
    private let enableMouse: Bool
    #if os(Windows)
    private var originalConsoleMode: DWORD = 0
    #else
    private var originalTermios = termios()
    #endif
    private var isActive = false
    private var running = false
    private var thread: Thread?

    /// Whether the terminal is currently reporting mouse events for this
    /// reader (raw mode is on and mouse reporting was requested).
    var isMouseTracking: Bool { isActive && enableMouse }

    /// Creates a reader that forwards each decoded event via `onEvent`.
    ///
    /// - Parameters:
    ///   - enableMouse: When `true`, terminal mouse reporting is enabled for
    ///     the session (full-screen sessions only — see ``KeyInputRouter``).
    ///   - onEvent: Invoked on the **main queue** for every event.
    init(enableMouse: Bool = false, onEvent: @escaping @Sendable (KeyEvent) -> Void) {
        self.enableMouse = enableMouse
        self.onEvent = onEvent
    }

    /// Enables raw mode and starts the background read loop.
    ///
    /// Does nothing when stdin is not an interactive console.
    func start() {
        #if os(Windows)
        let stdinHandle = GetStdHandle(STD_INPUT_HANDLE)
        var mode: DWORD = 0
        // GetConsoleMode fails when stdin is redirected (not a console); bail out.
        guard GetConsoleMode(stdinHandle, &mode) else { return }
        originalConsoleMode = mode
        // Raw mode: no echo, no line buffering, no ctrl-signal processing;
        // VT input sequences so escape codes reach _read() verbatim.
        let rawMode = (mode
            & ~DWORD(ENABLE_ECHO_INPUT)
            & ~DWORD(ENABLE_LINE_INPUT)
            & ~DWORD(ENABLE_PROCESSED_INPUT))
            | DWORD(ENABLE_VIRTUAL_TERMINAL_INPUT)
        SetConsoleMode(stdinHandle, rawMode)
        // VT output processing is required for ANSI sequences to render on Windows 10+.
        let stdoutHandle = GetStdHandle(STD_OUTPUT_HANDLE)
        var outMode: DWORD = 0
        if GetConsoleMode(stdoutHandle, &outMode) {
            SetConsoleMode(stdoutHandle, outMode
                | DWORD(ENABLE_PROCESSED_OUTPUT)
                | DWORD(ENABLE_VIRTUAL_TERMINAL_PROCESSING))
        }
        if enableMouse { TerminalOutput.write(MouseReporting.enableSequence) }
        TerminalRestoreGuard.arm(original: mode, mouseEnabled: enableMouse)
        #else
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
        if enableMouse {
            TerminalOutput.write(MouseReporting.enableSequence)
        }
        // Make sure the original settings come back even if the process exits
        // without reaching stop() — exit(), a crash, or a fatal signal.
        TerminalRestoreGuard.arm(original: originalTermios, mouseEnabled: enableMouse)
        #endif

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
        if enableMouse {
            TerminalOutput.write(MouseReporting.disableSequence)
        }
        #if os(Windows)
        SetConsoleMode(GetStdHandle(STD_INPUT_HANDLE), originalConsoleMode)
        #else
        tcsetattr(STDIN_FILENO, TCSANOW, &originalTermios)
        #endif
        TerminalRestoreGuard.disarm()
        isActive = false
    }

    // MARK: - Read loop

    private func loop() {
        var decoder = KeyDecoder()
        // 256 bytes fits ~17 SGR mouse events per read — important when the
        // kernel queues several events between loop iterations (rapid scroll).
        let bufSize = 256
        var buf = [UInt8](repeating: 0, count: bufSize)

        while running {
            #if os(Windows)
            let n = Int(_read(0, &buf, UInt32(bufSize)))
            #else
            let n = read(STDIN_FILENO, &buf, bufSize)
            #endif
            if n > 0 {
                let events = decoder.feed(Array(buf[0..<n]))
                if !events.isEmpty {
                    let cb = onEvent
                    // Batch all events decoded from one read() into a single
                    // main-queue task. This halves the async round-trips when
                    // the kernel queues multiple reports together (fast scroll
                    // or trackpad bursts), reducing dispatch overhead and lag.
                    DispatchQueue.main.async {
                        for event in events { cb(event) }
                    }
                }
            } else if n < 0 {
                // Read error; yield briefly and retry.
                Thread.sleep(forTimeInterval: 0.005)
            }
            // n == 0: the timed read returned no data (VTIME elapsed on Unix,
            // or a zero-byte read on Windows). Loop back to re-check `running`.
        }
    }
}
