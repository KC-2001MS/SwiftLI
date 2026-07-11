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
/// `InlineRenderer` is used internally by ``InlineCommand``. It drives the
/// intermediate-representation pipeline:
///
/// 1. Lower the view into a ``RenderNode`` tree.
/// 2. Lay the tree out into a ``Frame`` (the exact lines to display).
/// 3. Compare that frame against the previous one with ``FrameDiff`` and emit
///    only the escape sequences needed to update the lines that changed.
///
/// Because the diff rewrites just the changed lines, any `run()` output printed
/// **before** the body stays untouched, and live updates (progress bars,
/// spinners) never flicker.
final class InlineRenderer: @unchecked Sendable {

    // MARK: - State

    /// The most recently displayed frame, or `nil` before the first render.
    private var previousFrame: Frame?
    /// The terminal width used for the previous frame, to detect a resize.
    private var previousColumns: Int?
    /// The terminal height used for the previous frame, to detect a resize.
    private var previousRows: Int?
    private let lock = NSLock()

    // MARK: - Public interface

    /// Renders `view` for the first time or redraws it in-place.
    ///
    /// - Parameter view: The view to render.
    func render(_ view: any View) {
        lock.lock()
        defer { lock.unlock() }

        // Bracket the pass so the coordinator knows which controls are in
        // this frame — the idle check keeps the session alive while any are.
        FocusCoordinator.shared.beginRenderPass()
        defer { FocusCoordinator.shared.endRenderPass() }

        // Clip every line to one less than the terminal width. Leaving the last
        // column empty guarantees a trailing newline never triggers a wrap onto
        // a second physical row (some terminals wrap the moment the final column
        // is written), which would desync the in-place cursor arithmetic.
        let size = TerminalSize.current
        let columns = size.columns
        let clip = Swift.max(0, columns - 1)
        // Inline output has one fewer usable column than the terminal, so the
        // root `\.maxWidth` environment matches what will actually be shown.
        // Likewise one row is reserved below the body for the parked cursor,
        // so `\.maxHeight` matches the rows a vertical spacer may fill.
        var rootValues = EnvironmentValues()
        rootValues.maxWidth = clip
        rootValues.maxHeight = Swift.max(1, size.rows - 1)
        var frame = EnvironmentStack.with(rootValues) {
            NodeLayout.frame(of: view.makeNode())
        }
        frame.lines = frame.lines.map { TextMetrics.truncate($0, toColumns: clip) }
        // Clamp the body to the visible screen (one row is reserved for the
        // parked cursor below it). A taller body would scroll its first lines
        // off the top, where cursor-relative repaints can no longer reach —
        // every later diff would then land on the wrong rows.
        let maxLines = Swift.max(1, size.rows - 1)
        if frame.lines.count > maxLines {
            frame.lines = Array(frame.lines.prefix(maxLines))
        }

        let output: String
        if let previous = previousFrame, previousColumns == columns, previousRows == size.rows {
            // Same size → the per-line diff is valid; redraw only what changed.
            output = FrameDiff.inlineUpdate(from: previous, to: frame)
        } else if let previous = previousFrame {
            // The terminal was resized: the old block has reflowed, so fall back
            // to a physical-row-aware clean repaint instead of the per-line diff.
            output = FrameDiff.inlineRepaint(from: previous, to: frame, columns: columns)
        } else {
            // First render.
            output = FrameDiff.inlineUpdate(from: nil, to: frame)
        }

        TerminalOutput.write(output)
        previousFrame = frame
        previousColumns = columns
        previousRows = size.rows
    }

    /// Called once when body rendering is complete.
    ///
    /// The cursor is already parked on the line just below the finalized body
    /// after the last `render()`, so subsequent `print()` calls naturally
    /// appear beneath it. Resets state so a future render starts fresh.
    func finalize() {
        lock.lock()
        defer { lock.unlock() }
        previousFrame = nil
        previousColumns = nil
        previousRows = nil
    }
}
