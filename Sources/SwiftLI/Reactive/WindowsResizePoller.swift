//
//  WindowsResizePoller.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/12.
//

#if os(Windows)
import Foundation
import WinSDK

/// Polls the Windows console for window-size changes and fires `onResize`.
///
/// `SIGWINCH` is not available on Windows. `ReadConsoleInput` can deliver
/// `WINDOW_BUFFER_SIZE_EVENT`, but it reads from the same console input buffer
/// that `KeyboardReader` drains via `_read()` — using both simultaneously would
/// cause them to race for keyboard events. Instead, this poller calls
/// `GetConsoleScreenBufferInfo` at ~10 Hz (one syscall per 100 ms) and fires
/// `onResize` whenever the visible window rectangle changes. The callback is
/// always invoked on the main queue, matching SIGWINCH handler semantics.
final class WindowsResizePoller: @unchecked Sendable {

    private let onResize: @Sendable () -> Void
    private var running = false
    private var lastColumns: Int32 = 0
    private var lastRows: Int32 = 0
    private var thread: Thread?

    init(onResize: @escaping @Sendable () -> Void) {
        self.onResize = onResize
    }

    /// Captures the current size and starts the background polling thread.
    func start() {
        guard !running else { return }
        running = true
        let (c, r) = windowSize()
        lastColumns = c
        lastRows = r
        let t = Thread { [weak self] in self?.loop() }
        t.name = "SwiftLI.WindowsResizePoller"
        t.stackSize = 64 * 1024
        thread = t
        t.start()
    }

    /// Signals the polling thread to exit on its next iteration.
    func stop() {
        running = false
    }

    // MARK: - Private

    private func windowSize() -> (columns: Int32, rows: Int32) {
        var csbi = CONSOLE_SCREEN_BUFFER_INFO()
        guard GetConsoleScreenBufferInfo(GetStdHandle(STD_OUTPUT_HANDLE), &csbi) else {
            return (0, 0)
        }
        return (csbi.srWindow.Right - csbi.srWindow.Left + 1,
                csbi.srWindow.Bottom - csbi.srWindow.Top + 1)
    }

    private func loop() {
        while running {
            Thread.sleep(forTimeInterval: 0.1)
            guard running else { break }
            let (c, r) = windowSize()
            guard c > 0, c != lastColumns || r != lastRows else { continue }
            lastColumns = c
            lastRows = r
            let cb = onResize
            DispatchQueue.main.async { cb() }
        }
    }
}
#endif
