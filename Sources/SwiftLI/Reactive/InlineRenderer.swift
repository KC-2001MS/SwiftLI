//
//  InlineRenderer.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2024/05/27.
//

import Foundation

/// Renders a ``View`` inline in the terminal and redraws it in-place on
/// subsequent calls.
///
/// `InlineRenderer` is used internally by ``ViewableCommand``. It:
/// 1. Captures stdout during the first render to count the number of lines
///    the view occupies.
/// 2. On subsequent renders, moves the cursor up by that many lines and
///    overwrites the content.
///
/// This allows `run()` output printed **before** or **after** the body to
/// remain untouched — only the body region is refreshed.
final class InlineRenderer: @unchecked Sendable {

    // MARK: - State

    /// Number of newline-terminated lines the body produced on the last render.
    private var renderedLineCount: Int = 0
    private var hasRendered: Bool = false
    private let lock = NSLock()

    // MARK: - Public interface

    /// Renders `view` for the first time or redraws it in-place.
    ///
    /// The view is wrapped in an implicit root ``VStack`` (spacing 0, leading
    /// alignment) before rendering, making ``Group`` and top-level arrays
    /// behave like VStack children automatically.
    ///
    /// - Parameter view: The view to render.
    func render(_ view: any View) {
        lock.lock()
        defer { lock.unlock() }

        if hasRendered {
            // Move cursor up to the first line of the previous render,
            // then erase each line before redrawing
            if renderedLineCount > 0 {
                print("\u{001B}[\(renderedLineCount)A", terminator: "")
            }
            for _ in 0..<renderedLineCount {
                print("\u{001B}[2K", terminator: "")  // erase entire line
                print("\u{001B}[1B", terminator: "")  // move down one line
            }
            // Return cursor to the top of the body region
            if renderedLineCount > 0 {
                print("\u{001B}[\(renderedLineCount)A", terminator: "")
            }
        }

        // Wrap in an implicit root VStack so top-level views stack vertically
        let bodyGroup = view.body as? Group
        let children: [any View] = bodyGroup.map(\.contents) ?? [view]
        let root = VStack(spacing: 0, children: children.isEmpty ? [view] : children)
        // Capture stdout to count lines
        let lineCount = captureAndPrint(view: root)
        renderedLineCount = lineCount
        hasRendered = true
    }

    /// Called once when body rendering is complete.
    ///
    /// The cursor is already at the end of the last rendered line after
    /// `render()`, so no additional output is needed here.
    func finalize() {
        // No-op: cursor is already positioned after the last rendered line.
    }

    // MARK: - Private helpers

    /// Renders `view` to a String, counts newlines, then writes to stdout.
    /// Returns the number of lines printed.
    private func captureAndPrint(view: any View) -> Int {
        // Redirect stdout to a pipe so we can count lines
        let pipe = Pipe()
        let originalFd = dup(STDOUT_FILENO)
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)

        view.render()
        fflush(stdout)

        // Restore stdout
        dup2(originalFd, STDOUT_FILENO)
        close(originalFd)
        pipe.fileHandleForWriting.closeFile()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()

        // Write captured content to the real stdout
        FileHandle.standardOutput.write(data)
        fflush(stdout)

        // Count newlines to know how many lines were rendered
        let text = String(data: data, encoding: .utf8) ?? ""
        let lines = text.components(separatedBy: "\n")
        // Last element after split is empty if text ends with \n, so subtract 1
        let count = Swift.max(lines.count - 1, 0)
        return count
    }
}
