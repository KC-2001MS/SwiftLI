//
//  MouseTargetRegistry.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/12.
//

import Foundation

/// Records where each interactive control was drawn, so pointer events can be
/// routed to the control under the pointer.
///
/// Every control wraps its lowered node in ``RenderNode/control(id:child:)``;
/// when the layout engine draws that node it reports the child's rectangle
/// here. Containers that draw their children into an intermediate canvas (a
/// scroll viewport, a fixed frame) bracket the nested draw with
/// ``withTransform(translation:clip:_:)`` so the recorded rectangles land in
/// final screen coordinates — translated by the container's placement and
/// clipped to its visible window.
///
/// Like ``FocusCoordinator``'s visible-control set, regions are
/// double-buffered per render pass: ``hitTest(column:row:)`` always consults
/// the most recently *completed* frame, never a half-built one.
final class MouseTargetRegistry: @unchecked Sendable {

    /// The process-wide registry used by the reactive runtime.
    static let shared = MouseTargetRegistry()

    /// One control's on-screen footprint.
    struct Region: Equatable, Sendable {
        let id: String
        let rect: Rect
    }

    // MARK: - Sub-region roles

    /// Separates a control id from a sub-region role in a region id. Controls
    /// record their whole footprint under their bare id; a *part* of a control
    /// with its own pointer behaviour (a slider's track, a field's text run)
    /// records under `id␟role`, which routing splits back apart.
    static let roleSeparator: Character = "\u{1F}"

    /// A slider's track: a click maps the column to a value.
    static let trackRole = "track"
    /// A single-line field's text run: a click maps the column to a cursor index.
    static let textRole = "text"
    /// One text-editor line's text run (excluding the gutter): a click maps
    /// the position to a cursor line and column.
    static func lineRole(_ index: Int) -> String { "line:\(index)" }

    /// Builds the region id for a sub-region of control `id`.
    static func regionID(control id: String, role: String) -> String {
        id + String(roleSeparator) + role
    }

    /// Splits a region id into the owning control id and the sub-region role
    /// (`nil` for a control's whole footprint).
    static func parseRegionID(_ regionID: String) -> (id: String, role: String?) {
        guard let separator = regionID.firstIndex(of: roleSeparator) else {
            return (regionID, nil)
        }
        return (String(regionID[..<separator]), String(regionID[regionID.index(after: separator)...]))
    }

    private let lock = NSLock()
    /// Regions recorded by the pass in progress (`nil` outside a pass).
    private var currentPass: [Region]?
    /// Regions of the most recently completed pass — the frame on screen.
    private var regions: [Region] = []
    /// Render passes can nest; only the outermost bracket owns the pass.
    private var passDepth = 0
    /// The transform stack active while drawing into nested canvases. Drawing
    /// happens on a single thread within a pass, so a plain stack suffices.
    private var transforms: [(translation: Point, clip: Rect?)] = []
    /// The terminal row of the frame's first line. Zero for full-screen
    /// frames; an inline frame sits wherever the scrollback put it, resolved
    /// from a cursor-position report (see ``resolveInlineOrigin(parkedRow:)``).
    private var originRow = 0
    /// The height of the most recent inline frame, remembered between sending
    /// a cursor-position query and receiving its report. `nil` when no query
    /// is outstanding.
    private var pendingInlineHeight: Int?

    private init() {}

    // MARK: - Frame origin (screen → frame coordinate mapping)

    /// Declares that frames now start at the terminal's first row (the
    /// full-screen renderers call this every frame).
    func setFullScreenOrigin() {
        lock.lock(); defer { lock.unlock() }
        originRow = 0
        pendingInlineHeight = nil
    }

    /// Remembers the height of the inline frame just written, ahead of the
    /// cursor-position query that resolves where it starts.
    func noteInlineFrame(height: Int) {
        lock.lock(); defer { lock.unlock() }
        pendingInlineHeight = height
    }

    /// Resolves the inline frame's origin from a cursor-position report: the
    /// inline renderer parks the cursor on the row just below the frame, so
    /// the frame starts `height` rows above it. Ignored when no query is
    /// outstanding (a stray report, or a function key that encodes like one).
    func resolveInlineOrigin(parkedRow: Int) {
        lock.lock(); defer { lock.unlock() }
        guard let height = pendingInlineHeight else { return }
        pendingInlineHeight = nil
        originRow = Swift.max(0, parkedRow - height)
    }

    // MARK: - Render-pass bracketing

    /// Marks the start of a render pass; recordings until ``endPass()`` define
    /// the regions of the new frame.
    func beginPass() {
        lock.lock(); defer { lock.unlock() }
        passDepth += 1
        if passDepth == 1 {
            currentPass = []
            transforms = []
        }
    }

    /// Marks the end of a render pass, publishing the new frame's regions.
    func endPass() {
        lock.lock(); defer { lock.unlock() }
        passDepth = Swift.max(0, passDepth - 1)
        guard passDepth == 0 else { return }
        regions = currentPass ?? []
        currentPass = nil
    }

    /// Clears all recorded regions (called when the runtime tears down).
    func reset() {
        lock.lock(); defer { lock.unlock() }
        currentPass = nil
        regions.removeAll()
        transforms.removeAll()
        passDepth = 0
        originRow = 0
        pendingInlineHeight = nil
    }

    // MARK: - Recording (called from NodeLayout while drawing)

    /// Runs `body` with an additional coordinate transform: rectangles
    /// recorded inside are first clipped to `clip` (in the *outer* space,
    /// after translating), then shifted by `translation`.
    ///
    /// Used by containers that draw children into an intermediate canvas at
    /// the origin and then blit a window of it into place.
    func withTransform(translation: Point, clip: Rect?, _ body: () -> Void) {
        lock.lock()
        transforms.append((translation, clip))
        lock.unlock()
        defer {
            lock.lock()
            if !transforms.isEmpty { transforms.removeLast() }
            lock.unlock()
        }
        body()
    }

    /// Records the footprint of control `id`, mapping it through the active
    /// transforms. A rectangle fully clipped away is dropped. No-op outside a
    /// render pass.
    func record(id: String, rect: Rect) {
        lock.lock(); defer { lock.unlock() }
        guard currentPass != nil else { return }
        var mapped = rect
        // Innermost transform first: translate into the enclosing space, then
        // clip to the container's visible window there.
        for (translation, clip) in transforms.reversed() {
            mapped.origin.column += translation.column
            mapped.origin.row += translation.row
            if let clip {
                let minColumn = Swift.max(mapped.minColumn, clip.minColumn)
                let maxColumn = Swift.min(mapped.maxColumn, clip.maxColumn)
                let minRow = Swift.max(mapped.minRow, clip.minRow)
                let maxRow = Swift.min(mapped.maxRow, clip.maxRow)
                guard minColumn < maxColumn, minRow < maxRow else { return }
                mapped = Rect(
                    origin: Point(column: minColumn, row: minRow),
                    size: Size(width: maxColumn - minColumn, height: maxRow - minRow)
                )
            }
        }
        guard mapped.size.width > 0, mapped.size.height > 0 else { return }
        currentPass?.append(Region(id: id, rect: mapped))
    }

    // MARK: - Hit testing

    /// The terminal row of the frame's first line — subtract it from a mouse
    /// report's row to get frame coordinates. Zero for full-screen frames.
    var frameOriginRow: Int {
        lock.lock(); defer { lock.unlock() }
        return originRow
    }

    /// Every region containing the point (in **frame** coordinates), topmost
    /// first.
    ///
    /// Regions are recorded in draw order, and later draws paint over earlier
    /// ones — so the *last* recorded match is the control actually visible at
    /// the point (a sheet's button over the base layer's), and enclosing
    /// containers (a scroll view around a clicked button) follow after it.
    func hits(atColumn column: Int, row: Int) -> [Region] {
        lock.lock(); defer { lock.unlock() }
        return regions.reversed().filter { region in
            column >= region.rect.minColumn && column < region.rect.maxColumn
                && row >= region.rect.minRow && row < region.rect.maxRow
        }
    }

    /// The topmost control at the point, or `nil` when the point is empty.
    func hitTest(column: Int, row: Int) -> Region? {
        hits(atColumn: column, row: row).first
    }

    /// The most recently drawn region with exactly this id, or `nil` when the
    /// current frame doesn't contain it.
    ///
    /// Used by drag tracking: a drag captured on a press keeps following the
    /// control's *current* rectangle, which may shift between frames (gaining
    /// focus adds the `> ` marker, moving everything right).
    func region(withID id: String) -> Region? {
        lock.lock(); defer { lock.unlock() }
        return regions.last { $0.id == id }
    }
}

// MARK: - HitRegion

/// Marks a *part* of a control (a slider's track, a field's text run) as a
/// pointer sub-region: the content lowers unchanged, wrapped in a
/// ``RenderNode/control(id:child:)`` whose id is `controlID␟role`.
///
/// Built-in styles use it so clicks can be mapped to a position *within* the
/// control. A `nil` `controlID` (a style rendered outside any control) lowers
/// the content untouched.
struct HitRegion: View, @unchecked Sendable {
    let controlID: String?
    let role: String
    let content: any View

    var body: some View {
        EmptyView()
    }

    func makeNode() -> RenderNode {
        let node = content.makeNode()
        guard let controlID else { return node }
        return node.asControl(id: MouseTargetRegistry.regionID(control: controlID, role: role))
    }
}
