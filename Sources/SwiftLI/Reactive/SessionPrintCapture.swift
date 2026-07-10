//
//  SessionPrintCapture.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/10.
//

import Foundation

/// Writes renderer output to the real terminal, bypassing any active
/// ``SessionPrintCapture`` redirection of `stdout`.
///
/// While a rendering session captures `stdout`, file descriptor 1 feeds a
/// pipe — so the renderers must not write through `print`/`stdout` or their
/// own escape output would be captured too. They write here instead: `fd` is
/// the process's stdout by default and the saved terminal descriptor while a
/// capture is active.
enum TerminalOutput {
    /// Where renderer output goes. Only ``SessionPrintCapture`` mutates this.
    nonisolated(unsafe) static var fd: Int32 = STDOUT_FILENO

    /// Writes `string` to the terminal, looping over partial writes.
    static func write(_ string: String) {
        let bytes = Array(string.utf8)
        var offset = 0
        while offset < bytes.count {
            let written = bytes[offset...].withUnsafeBytes { buffer in
                Darwin.write(fd, buffer.baseAddress, buffer.count)
            }
            if written <= 0 { return }
            offset += written
        }
    }
}

/// Captures `print()` output while a rendering session is active, so user
/// code printing from `run()` cannot corrupt the live display.
///
/// The session's renderer repaints in place using cursor arithmetic (inline)
/// or paints the alternate screen (full-screen); raw `print` output landing at
/// the cursor position would desynchronise both. On ``start(handler:)`` the
/// capture redirects file descriptor 1 into a pipe, points
/// ``TerminalOutput/fd`` at the saved terminal descriptor for the renderers,
/// and drains the pipe on a background thread, delivering the captured text to
/// `handler` one complete line at a time:
///
/// - An inline session inserts each line *above* the live body
///   (``InlineRenderer/printAbove(_:)``), keeping it in the scrollback.
/// - A full-screen session buffers the lines and replays them onto the normal
///   screen after the alternate screen is left, so nothing is lost.
final class SessionPrintCapture: @unchecked Sendable {
    static let shared = SessionPrintCapture()

    private let lock = NSLock()
    private var savedStdout: Int32 = -1
    private var readEnd: Int32 = -1
    private var drained: DispatchSemaphore?
    private var active = false

    private init() {}

    /// Redirects `stdout` into a pipe and delivers every captured line
    /// (newline included) to `handler` on the drain thread.
    ///
    /// - Returns: `false` when the redirection could not be established (the
    ///   session then simply runs without capture, as before).
    @discardableResult
    func start(handler: @escaping @Sendable (String) -> Void) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !active else { return false }

        var fds: [Int32] = [0, 0]
        guard pipe(&fds) == 0 else { return false }
        let saved = dup(STDOUT_FILENO)
        guard saved >= 0 else {
            close(fds[0]); close(fds[1])
            return false
        }
        fflush(stdout)
        guard dup2(fds[1], STDOUT_FILENO) >= 0 else {
            close(fds[0]); close(fds[1]); close(saved)
            return false
        }
        close(fds[1])
        // stdout now feeds a pipe (not a TTY), which would switch stdio to
        // full buffering — force line buffering so prints arrive promptly.
        setvbuf(stdout, nil, _IOLBF, 0)

        savedStdout = saved
        readEnd = fds[0]
        TerminalOutput.fd = saved
        active = true

        let readFD = fds[0]
        let done = DispatchSemaphore(value: 0)
        drained = done
        Thread.detachNewThread {
            var pending: [UInt8] = []
            var buffer = [UInt8](repeating: 0, count: 4096)
            while true {
                let count = read(readFD, &buffer, buffer.count)
                if count <= 0 { break }
                pending.append(contentsOf: buffer[0..<count])
                // Deliver complete lines; keep a partial tail (and any split
                // UTF-8 sequence) for the next read.
                while let newline = pending.firstIndex(of: 0x0A) {
                    let line = pending[...newline]
                    pending.removeSubrange(...newline)
                    handler(String(decoding: line, as: UTF8.self))
                }
            }
            if !pending.isEmpty {
                handler(String(decoding: pending, as: UTF8.self) + "\n")
            }
            done.signal()
        }
        return true
    }

    /// Restores `stdout`, waits until every captured byte has been delivered
    /// to the handler, and tears the pipe down.
    func stop() {
        lock.lock()
        guard active else {
            lock.unlock()
            return
        }
        active = false
        let saved = savedStdout
        let readFD = readEnd
        let done = drained
        savedStdout = -1
        readEnd = -1
        drained = nil
        lock.unlock()

        fflush(stdout)                  // push straggling stdio bytes into the pipe
        dup2(saved, STDOUT_FILENO)      // the pipe loses its last writer → EOF
        setvbuf(stdout, nil, _IOLBF, 0)
        TerminalOutput.fd = STDOUT_FILENO
        close(saved)
        done?.wait()                    // the drain thread has delivered everything
        close(readFD)
    }
}
