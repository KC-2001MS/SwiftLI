//
//  MouseTests.swift
//  SwiftLITests
//
//  Created by Keisuke Chinone on 2026/07/12.
//

#if swift(>=6.0)
import Testing
@_spi(RenderingInternals) @testable import SwiftLI
import Foundation

// MARK: - Mouse sequence decoding (pure state machine — no singletons)

@Suite("Mouse Decoding Testing")
struct MouseDecodingTests {
    /// Feeds a string's UTF-8 bytes through a fresh decoder.
    private func decode(_ s: String) -> [KeyEvent] {
        var decoder = KeyDecoder()
        return decoder.feed(Array(s.utf8))
    }

    @Test("An SGR press report decodes with 0-based coordinates")
    func sgrPress() {
        let events = decode("\u{1B}[<0;5;3M")
        #expect(events == [.mouse(MouseEvent(kind: .press(.left), column: 4, row: 2))])
    }

    @Test("SGR release ('m' final) and the right button decode")
    func sgrRelease() {
        let events = decode("\u{1B}[<2;1;1m")
        #expect(events == [.mouse(MouseEvent(kind: .release(.right), column: 0, row: 0))])
    }

    @Test("SGR wheel reports decode to scrollUp / scrollDown")
    func sgrWheel() {
        #expect(decode("\u{1B}[<64;10;4M") == [.mouse(MouseEvent(kind: .scrollUp, column: 9, row: 3))])
        #expect(decode("\u{1B}[<65;10;4M") == [.mouse(MouseEvent(kind: .scrollDown, column: 9, row: 3))])
    }

    @Test("An SGR motion report with a held button decodes as a drag")
    func sgrDrag() {
        let events = decode("\u{1B}[<32;7;2M")
        #expect(events == [.mouse(MouseEvent(kind: .drag(.left), column: 6, row: 1))])
    }

    @Test("Modifier bits (Shift/Alt/Ctrl) don't change the decoded button")
    func sgrModifiers() {
        // 16 = Ctrl held during a left press.
        let events = decode("\u{1B}[<16;2;2M")
        #expect(events == [.mouse(MouseEvent(kind: .press(.left), column: 1, row: 1))])
    }

    @Test("A report split across feeds is buffered until complete")
    func splitFeed() {
        var decoder = KeyDecoder()
        #expect(decoder.feed(Array("\u{1B}[<0;12".utf8)).isEmpty)
        let events = decoder.feed(Array(";7M".utf8))
        #expect(events == [.mouse(MouseEvent(kind: .press(.left), column: 11, row: 6))])
    }

    @Test("A legacy X10 report decodes, and its payload is not re-read as text")
    func x10Press() {
        var decoder = KeyDecoder()
        // ESC [ M, then button+32, column+33, row+33 — a left press at (4, 2).
        let events = decoder.feed([0x1B, 0x5B, 0x4D, 32, UInt8(33 + 4), UInt8(33 + 2)])
        #expect(events == [.mouse(MouseEvent(kind: .press(.left), column: 4, row: 2))])
    }

    @Test("Keys following a mouse report still decode")
    func mixedStream() {
        let events = decode("\u{1B}[<0;1;1Ma")
        #expect(events == [
            .mouse(MouseEvent(kind: .press(.left), column: 0, row: 0)),
            .character("a"),
        ])
    }

    @Test("A cursor-position report decodes with 0-based coordinates")
    func cursorPositionReport() {
        #expect(decode("\u{1B}[12;1R") == [.cursorPosition(row: 11, column: 0)])
        // A bare CSI R (no parameters — some terminals' F3) is not a report.
        #expect(decode("\u{1B}[R") == [])
    }
}

// MARK: - Shared-singleton suites (registry + coordinator)

extension ControlSingletonTests {

@Suite("Mouse Target Registry Testing", .serialized)
struct MouseTargetRegistryTests {
    @Test("A recorded region is hit-testable after the pass completes")
    func recordAndHit() {
        let registry = MouseTargetRegistry.shared
        registry.reset()
        defer { registry.reset() }

        registry.beginPass()
        registry.record(id: "button", rect: Rect(origin: Point(column: 2, row: 1), size: Size(width: 10, height: 1)))
        // Not published until the pass ends.
        #expect(registry.hitTest(column: 2, row: 1) == nil)
        registry.endPass()

        #expect(registry.hitTest(column: 2, row: 1)?.id == "button")
        #expect(registry.hitTest(column: 11, row: 1)?.id == "button")
        #expect(registry.hitTest(column: 12, row: 1) == nil)   // just past the edge
        #expect(registry.hitTest(column: 2, row: 0) == nil)
    }

    @Test("The last-drawn region wins at an overlapping point")
    func topmostWins() {
        let registry = MouseTargetRegistry.shared
        registry.reset()
        defer { registry.reset() }

        registry.beginPass()
        registry.record(id: "under", rect: Rect(origin: .zero, size: Size(width: 20, height: 5)))
        registry.record(id: "over", rect: Rect(origin: Point(column: 5, row: 2), size: Size(width: 4, height: 1)))
        registry.endPass()

        let hits = registry.hits(atColumn: 6, row: 2)
        #expect(hits.map(\.id) == ["over", "under"])
    }

    @Test("A scroll-style transform translates and clips recorded regions")
    func transformMapsIntoViewport() {
        let registry = MouseTargetRegistry.shared
        registry.reset()
        defer { registry.reset() }

        // A 3-row viewport at row 10, scrolled down by 2 content rows.
        registry.beginPass()
        registry.withTransform(
            translation: Point(column: 0, row: 10 - 2),
            clip: Rect(origin: Point(column: 0, row: 10), size: Size(width: 100, height: 3))
        ) {
            // Content row 1: scrolled above the viewport → clipped away.
            registry.record(id: "above", rect: Rect(origin: Point(column: 0, row: 1), size: Size(width: 5, height: 1)))
            // Content row 3: lands on screen row 11.
            registry.record(id: "visible", rect: Rect(origin: Point(column: 0, row: 3), size: Size(width: 5, height: 1)))
        }
        registry.endPass()

        #expect(registry.hitTest(column: 0, row: 9) == nil)
        #expect(registry.hitTest(column: 0, row: 11)?.id == "visible")
        #expect(registry.hits(atColumn: 0, row: 10).isEmpty)   // "above" was clipped
    }

    @Test("Rendering a frame records the footprints of the controls in it")
    func layoutRecordsControls() {
        let coord = FocusCoordinator.shared
        let registry = MouseTargetRegistry.shared
        coord.reset()
        defer { coord.reset() }

        // beginRenderPass drives the registry's pass in lockstep.
        coord.beginRenderPass()
        let node = RenderNode.vstack(alignment: .leading, spacing: 0, children: [
            .text(style: .plain, contents: ["headline"]),
            .control(id: "ok", child: .text(style: .plain, contents: ["[ OK ]"])),
        ])
        _ = NodeLayout.frame(of: node)
        coord.endRenderPass()

        #expect(registry.hitTest(column: 0, row: 0) == nil)          // plain text
        #expect(registry.hitTest(column: 2, row: 1)?.id == "ok")     // the control's row
    }
}

@Suite("Mouse Routing Testing", .serialized)
struct MouseRoutingTests {
    /// Publishes one region for `id` so hit-testing finds it.
    private func publish(_ id: String, rect: Rect) {
        let registry = MouseTargetRegistry.shared
        registry.beginPass()
        registry.record(id: id, rect: rect)
        registry.endPass()
    }

    @Test("A click on a button focuses it and fires its action")
    func clickFiresButton() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }

        let fired = StringBox("no")
        let box = StringBox("")
        coord.register(id: "field", binding: Binding(get: { box.value }, set: { box.value = $0 }), onSubmit: nil)
        coord.registerButton(id: "ok") { fired.value = "yes" }
        publish("ok", rect: Rect(origin: Point(column: 4, row: 3), size: Size(width: 6, height: 1)))

        #expect(coord.isFocused("field"))   // first control auto-focused
        let handled = coord.handleMouse(MouseEvent(kind: .press(.left), column: 5, row: 3))
        #expect(handled)
        #expect(fired.value == "yes")
        #expect(coord.isFocused("ok"))
    }

    @Test("A click outside every control is not consumed")
    func clickOnNothing() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }

        coord.registerButton(id: "ok") {}
        publish("ok", rect: Rect(origin: .zero, size: Size(width: 6, height: 1)))

        #expect(!coord.handleMouse(MouseEvent(kind: .press(.left), column: 50, row: 20)))
        #expect(coord.isFocused("ok"))   // focus unchanged (auto-focus)
    }

    @Test("A click on a toggle flips its binding")
    func clickFlipsToggle() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }

        let box = BoolBox(false)
        coord.registerToggle(id: "toggle", isOn: Binding(get: { box.value }, set: { box.value = $0 }))
        publish("toggle", rect: Rect(origin: .zero, size: Size(width: 12, height: 1)))

        #expect(coord.handleMouse(MouseEvent(kind: .press(.left), column: 3, row: 0)))
        #expect(box.value == true)
    }

    @Test("A click on a picker advances to the next option")
    func clickAdvancesPicker() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }

        let box = IntBox(2)
        coord.registerPicker(id: "picker", selection: Binding(get: { box.value }, set: { box.value = $0 }), count: 3)
        publish("picker", rect: Rect(origin: .zero, size: Size(width: 20, height: 1)))

        #expect(coord.handleMouse(MouseEvent(kind: .press(.left), column: 0, row: 0)))
        #expect(box.value == 0)   // wraps from the last option
    }

    @Test("A click on a one-line-per-row list selects the clicked row")
    func clickSelectsListRow() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }

        let box = OptionalIntBox(nil)
        coord.registerList(id: "list", selection: Binding(get: { box.value }, set: { box.value = $0 }), count: 5, viewportRows: nil)
        publish("list", rect: Rect(origin: Point(column: 0, row: 2), size: Size(width: 20, height: 5)))

        #expect(coord.handleMouse(MouseEvent(kind: .press(.left), column: 1, row: 4)))
        #expect(box.value == 2)
        #expect(coord.isFocused("list"))
    }

    @Test("The wheel scrolls the scroll view under the pointer, without focusing it")
    func wheelScrollsViewport() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }

        let box = StringBox("")
        coord.register(id: "field", binding: Binding(get: { box.value }, set: { box.value = $0 }), onSubmit: nil)
        coord.registerScroll(id: "scroll", viewportHeight: 5, contentHeight: 30)
        publish("scroll", rect: Rect(origin: Point(column: 0, row: 1), size: Size(width: 40, height: 5)))

        #expect(coord.handleMouse(MouseEvent(kind: .scrollDown, column: 3, row: 2)))
        #expect(coord.scrollOffset(for: "scroll") == 1)
        #expect(coord.handleMouse(MouseEvent(kind: .scrollUp, column: 3, row: 2)))
        #expect(coord.scrollOffset(for: "scroll") == 0)
        // Clamped at the top; still consumed.
        #expect(coord.handleMouse(MouseEvent(kind: .scrollUp, column: 3, row: 2)))
        #expect(coord.scrollOffset(for: "scroll") == 0)
        // Focus never moved to the scroll view.
        #expect(coord.isFocused("field"))
    }

    @Test("The wheel over a scrolling list moves its row window")
    func wheelScrollsList() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }

        let box = OptionalIntBox(0)
        coord.registerList(id: "list", selection: Binding(get: { box.value }, set: { box.value = $0 }), count: 10, viewportRows: 4)
        publish("list", rect: Rect(origin: .zero, size: Size(width: 20, height: 4)))

        #expect(coord.handleMouse(MouseEvent(kind: .scrollDown, column: 0, row: 0)))
        #expect(coord.listOffset(for: "list") == 1)
        #expect(box.value == 0)   // wheel scrolls the window, not the selection
    }

    @Test("A click on a slider's track jumps the value to the clicked column")
    func trackClickSetsSliderValue() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }

        let box = DoubleBox(0)
        coord.registerSlider(id: "slider", value: Binding(get: { box.value }, set: { box.value = $0 }), range: 0...100, step: 10)
        // An 11-column track: column index i maps to value i × 10.
        let registry = MouseTargetRegistry.shared
        registry.beginPass()
        registry.record(id: "slider", rect: Rect(origin: .zero, size: Size(width: 20, height: 1)))
        registry.record(id: MouseTargetRegistry.regionID(control: "slider", role: MouseTargetRegistry.trackRole),
                        rect: Rect(origin: Point(column: 9, row: 0), size: Size(width: 11, height: 1)))
        registry.endPass()

        #expect(coord.handleMouse(MouseEvent(kind: .press(.left), column: 9 + 7, row: 0)))
        #expect(box.value == 70)
        #expect(coord.isFocused("slider"))
        // Click on the label (the control, outside the track): focus only.
        #expect(coord.handleMouse(MouseEvent(kind: .press(.left), column: 0, row: 0)))
        #expect(box.value == 70)
    }

    @Test("A click inside a field's text moves the cursor, wide characters included")
    func textClickMovesCursor() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }

        let box = StringBox("ab漢c")
        coord.register(id: "field", binding: Binding(get: { box.value }, set: { box.value = $0 }), onSubmit: nil)
        let registry = MouseTargetRegistry.shared
        registry.beginPass()
        registry.record(id: "field", rect: Rect(origin: .zero, size: Size(width: 20, height: 1)))
        // The text run starts after the 2-column marker. When focused the
        // rendered run includes the block-cursor cell, so give the region a
        // little slack past the text itself.
        registry.record(id: MouseTargetRegistry.regionID(control: "field", role: MouseTargetRegistry.textRole),
                        rect: Rect(origin: Point(column: 2, row: 0), size: Size(width: 8, height: 1)))
        registry.endPass()

        // Cells: a(2) b(3) 漢(4-5) c(6). Clicking either half of 漢 → index 2.
        #expect(coord.handleMouse(MouseEvent(kind: .press(.left), column: 5, row: 0)))
        #expect(coord.cursor(for: "field") == 2)
        // Clicking c → index 3; past the end → index 4 (after the last char).
        #expect(coord.handleMouse(MouseEvent(kind: .press(.left), column: 6, row: 0)))
        #expect(coord.cursor(for: "field") == 3)
        #expect(coord.handleMouse(MouseEvent(kind: .press(.left), column: 9, row: 0)))
        #expect(coord.cursor(for: "field") == 4)
    }

    @Test("A click on an editor line places the cursor at that line and column")
    func editorLineClickMovesCursor() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }

        let box = StringBox("first\nsecond\nthird")
        coord.register(id: "editor",
                       binding: Binding(get: { box.value }, set: { box.value = $0 }),
                       onSubmit: nil,
                       keymap: MultiLineKeymap())
        let registry = MouseTargetRegistry.shared
        registry.beginPass()
        registry.record(id: "editor", rect: Rect(origin: .zero, size: Size(width: 20, height: 3)))
        // Each line's text starts after the 2-column gutter.
        for (index, width) in [5, 6, 5].enumerated() {
            registry.record(id: MouseTargetRegistry.regionID(control: "editor", role: MouseTargetRegistry.lineRole(index)),
                            rect: Rect(origin: Point(column: 2, row: index), size: Size(width: width, height: 1)))
        }
        registry.endPass()

        // Click "second", column 3 → flat offset = 5 ("first") + 1 + 3 = 9.
        #expect(coord.handleMouse(MouseEvent(kind: .press(.left), column: 2 + 3, row: 1)))
        #expect(coord.cursor(for: "editor") == 9)
        // Click past the end of "third" clamps to the line's length.
        #expect(coord.handleMouse(MouseEvent(kind: .press(.left), column: 2 + 4, row: 2)))
        #expect(coord.cursor(for: "editor") == 5 + 1 + 6 + 1 + 4)
    }

    @Test("Sub-regions are recorded when a slider and a field render")
    func stylesRecordSubRegions() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }

        let slider = DoubleBox(0.5)
        let text = StringBox("hello")
        coord.beginRenderPass()
        let node = RenderNode.vstack(alignment: .leading, spacing: 0, children: [
            Slider("Volume", value: Binding(get: { slider.value }, set: { slider.value = $0 }), width: 10).makeNode(),
            TextField("Name", text: Binding(get: { text.value }, set: { text.value = $0 })).makeNode(),
        ])
        _ = NodeLayout.frame(of: node)
        coord.endRenderPass()

        let registry = MouseTargetRegistry.shared
        // Row 0: "> Volume ━━●──────" — the slider auto-focuses as the first
        // control, so the track follows the marker, label, and gap. Column 12
        // is inside the 10-column track wherever the chrome puts it.
        let trackHits = registry.hits(atColumn: 12, row: 0).map(\.id)
        #expect(trackHits.contains(MouseTargetRegistry.regionID(control: "Volume", role: MouseTargetRegistry.trackRole)))
        #expect(trackHits.contains("Volume"))
        // Row 1: "  hello" — the text region sits after the 2-column marker.
        let textHits = registry.hits(atColumn: 3, row: 1).map(\.id)
        #expect(textHits.contains(MouseTargetRegistry.regionID(control: "Name", role: MouseTargetRegistry.textRole)))
        #expect(textHits.contains("Name"))
    }

    @Test("An inline frame's origin shifts hit-testing by the resolved row")
    func inlineOriginTranslatesHits() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }

        let fired = StringBox("no")
        coord.registerButton(id: "ok") { fired.value = "yes" }
        let registry = MouseTargetRegistry.shared
        registry.beginPass()
        registry.record(id: "ok", rect: Rect(origin: .zero, size: Size(width: 6, height: 1)))
        registry.endPass()

        // A 1-row frame whose parked cursor reported row 10 → frame row 0 is
        // screen row 9.
        registry.noteInlineFrame(height: 1)
        registry.resolveInlineOrigin(parkedRow: 10)
        #expect(registry.frameOriginRow == 9)

        // A click at screen row 0 misses; at screen row 9 it fires.
        #expect(!coord.handleMouse(MouseEvent(kind: .press(.left), column: 0, row: 0)))
        #expect(coord.handleMouse(MouseEvent(kind: .press(.left), column: 0, row: 9)))
        #expect(fired.value == "yes")

        // A report with no outstanding query is ignored.
        registry.resolveInlineOrigin(parkedRow: 42)
        #expect(registry.frameOriginRow == 9)
    }

    @Test("A press on a slider's track captures the pointer; drags follow, release lets go")
    func dragFollowsSliderTrack() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }

        let box = DoubleBox(0)
        coord.registerSlider(id: "slider", value: Binding(get: { box.value }, set: { box.value = $0 }), range: 0...100, step: 1)
        // An 11-column track at column 10: track index i maps to value i × 10.
        let trackID = MouseTargetRegistry.regionID(control: "slider", role: MouseTargetRegistry.trackRole)
        let registry = MouseTargetRegistry.shared
        registry.beginPass()
        registry.record(id: trackID, rect: Rect(origin: Point(column: 10, row: 0), size: Size(width: 11, height: 1)))
        registry.endPass()

        // Press at track index 2, then drag to index 5.
        #expect(coord.handleMouse(MouseEvent(kind: .press(.left), column: 12, row: 0)))
        #expect(box.value == 20)
        #expect(coord.handleMouse(MouseEvent(kind: .drag(.left), column: 15, row: 0)))
        #expect(box.value == 50)
        // Dragging past either end pins the value there.
        #expect(coord.handleMouse(MouseEvent(kind: .drag(.left), column: 60, row: 3)))
        #expect(box.value == 100)
        #expect(coord.handleMouse(MouseEvent(kind: .drag(.left), column: 0, row: 0)))
        #expect(box.value == 0)
        // Release ends the capture; further drags are not consumed.
        #expect(!coord.handleMouse(MouseEvent(kind: .release(.left), column: 0, row: 0)))
        #expect(!coord.handleMouse(MouseEvent(kind: .drag(.left), column: 15, row: 0)))
        #expect(box.value == 0)
    }

    @Test("A dragged slider tracks its current rectangle, not the one at press time")
    func dragTracksCurrentRect() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }

        let box = DoubleBox(0)
        coord.registerSlider(id: "slider", value: Binding(get: { box.value }, set: { box.value = $0 }), range: 0...100, step: 1)
        let trackID = MouseTargetRegistry.regionID(control: "slider", role: MouseTargetRegistry.trackRole)
        let registry = MouseTargetRegistry.shared
        registry.beginPass()
        registry.record(id: trackID, rect: Rect(origin: Point(column: 10, row: 0), size: Size(width: 11, height: 1)))
        registry.endPass()

        #expect(coord.handleMouse(MouseEvent(kind: .press(.left), column: 10, row: 0)))
        #expect(box.value == 0)

        // Gaining focus re-renders the slider two columns to the right (the
        // "> " marker). The next drag must map against the new rectangle.
        registry.beginPass()
        registry.record(id: trackID, rect: Rect(origin: Point(column: 12, row: 0), size: Size(width: 11, height: 1)))
        registry.endPass()

        #expect(coord.handleMouse(MouseEvent(kind: .drag(.left), column: 17, row: 0)))
        #expect(box.value == 50)   // column 17 is index 5 of the shifted track
    }

    @Test("A press elsewhere supersedes a stale drag capture")
    func pressClearsDragCapture() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }

        let box = DoubleBox(0)
        coord.registerSlider(id: "slider", value: Binding(get: { box.value }, set: { box.value = $0 }), range: 0...100, step: 1)
        coord.registerButton(id: "ok") {}
        let trackID = MouseTargetRegistry.regionID(control: "slider", role: MouseTargetRegistry.trackRole)
        let registry = MouseTargetRegistry.shared
        registry.beginPass()
        registry.record(id: trackID, rect: Rect(origin: Point(column: 10, row: 0), size: Size(width: 11, height: 1)))
        registry.record(id: "ok", rect: Rect(origin: Point(column: 0, row: 2), size: Size(width: 6, height: 1)))
        registry.endPass()

        // Capture the slider, then press the button (its release was lost).
        #expect(coord.handleMouse(MouseEvent(kind: .press(.left), column: 10, row: 0)))
        #expect(coord.handleMouse(MouseEvent(kind: .press(.left), column: 1, row: 2)))
        // The old capture is gone: a drag no longer moves the slider.
        #expect(!coord.handleMouse(MouseEvent(kind: .drag(.left), column: 15, row: 0)))
        #expect(box.value == 0)
    }

    @Test("Motion and release events are ignored")
    func motionIgnored() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }

        coord.registerButton(id: "ok") { Issue.record("a drag must not fire the action") }
        publish("ok", rect: Rect(origin: .zero, size: Size(width: 6, height: 1)))

        #expect(!coord.handleMouse(MouseEvent(kind: .drag(.left), column: 0, row: 0)))
        #expect(!coord.handleMouse(MouseEvent(kind: .release(.left), column: 0, row: 0)))
        #expect(!coord.handleMouse(MouseEvent(kind: .move, column: 0, row: 0)))
    }
}

}
#endif
