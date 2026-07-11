//
//  ControlTests.swift
//  SwiftLITests
//
//  Created by Keisuke Chinone on 2026/07/10.
//

#if swift(>=6.0)
import Testing
@_spi(RenderingInternals) @testable import SwiftLI
import Foundation

// MARK: - Focus coordinator routing (shared singleton → serialized)

/// These tests drive the process-wide ``FocusCoordinator/shared`` singleton, so
/// they must not run in parallel with one another.
// MARK: - Shared-singleton serialization domain

/// Every suite nested here drives process-wide singletons
/// (``FocusCoordinator/shared``, ``BodyRenderingStore/shared``), so the whole
/// domain is serialized — suites in different domains may otherwise run in
/// parallel and reset each other's coordinator state mid-test.
@Suite("Control Singleton Testing", .serialized)
struct ControlSingletonTests {}

extension ControlSingletonTests {
@Suite("Focus Coordinator Testing", .serialized)
struct FocusCoordinatorTests {
    @Test("Keys route to the focused field's binding")
    func editsBinding() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }

        let box = StringBox("")
        coord.register(id: "field", binding: Binding(get: { box.value }, set: { box.value = $0 }), onSubmit: nil)

        #expect(coord.isFocused("field"))
        _ = coord.handle(.character("A"))
        _ = coord.handle(.character("B"))
        #expect(box.value == "AB")
        _ = coord.handle(.backspace)
        #expect(box.value == "A")
    }

    @Test("Tab moves focus to the next registered field")
    func tabMovesFocus() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }

        let a = StringBox(""), b = StringBox("")
        coord.register(id: "a", binding: Binding(get: { a.value }, set: { a.value = $0 }), onSubmit: nil)
        coord.register(id: "b", binding: Binding(get: { b.value }, set: { b.value = $0 }), onSubmit: nil)

        #expect(coord.isFocused("a"))
        _ = coord.handle(.tab)
        #expect(coord.isFocused("b"))
        _ = coord.handle(.character("z"))
        #expect(b.value == "z")
        #expect(a.value == "")
    }

    @Test("Enter invokes a single-line field's onSubmit")
    func enterSubmits() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }

        let submitted = StringBox("no")
        let box = StringBox("")
        coord.register(id: "field",
                       binding: Binding(get: { box.value }, set: { box.value = $0 }),
                       onSubmit: { submitted.value = "yes" })
        _ = coord.handle(.enter)
        #expect(submitted.value == "yes")
    }

    @Test("A multi-line field inserts a newline on Return instead of submitting")
    func returnRoutesByKind() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }

        let box = StringBox("ab")
        coord.register(id: "editor",
                       binding: Binding(get: { box.value }, set: { box.value = $0 }),
                       onSubmit: nil,
                       keymap: MultiLineKeymap())
        _ = coord.handle(.enter)
        #expect(box.value == "ab\n")
    }

    @Test("A focused toggle flips on Space and is set by arrows and y/n")
    func toggleControl() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }

        let box = BoolBox(true)
        coord.registerToggle(id: "t", isOn: Binding(get: { box.value }, set: { box.value = $0 }))

        #expect(coord.isFocused("t"))
        _ = coord.handle(.character(" "))         // flip true → false
        #expect(box.value == false)
        _ = coord.handle(.left)                   // Left = on
        #expect(box.value == true)
        _ = coord.handle(.right)                  // Right = off
        #expect(box.value == false)
        _ = coord.handle(.character("y"))
        #expect(box.value == true)
        _ = coord.handle(.character("n"))
        #expect(box.value == false)
    }

    /// Registers a text control wired to a shared focus token, emulating what a
    /// `.focused($token, equals: id)` modifier does around a `TextField`.
    private func registerFocused(_ coord: FocusCoordinator, id: String, token: StringBox) {
        coord.pushFocus(
            onFocus: { if token.value != id { token.value = id } },
            onUnfocus: { if token.value == id { token.value = "" } },
            isRequested: { token.value == id }
        )
        let text = StringBox("")
        coord.register(id: id, binding: Binding(get: { text.value }, set: { text.value = $0 }), onSubmit: nil)
        coord.popFocus()
    }

    @Test("Tab writes the focused control's value back through @FocusState")
    func focusStateTabWriteback() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }

        let token = StringBox("")
        registerFocused(coord, id: "a", token: token)
        registerFocused(coord, id: "b", token: token)

        #expect(coord.isFocused("a"))
        #expect(token.value == "")          // auto-initial focus doesn't clobber the binding
        _ = coord.handle(.tab)              // a → b, written back
        #expect(coord.isFocused("b"))
        #expect(token.value == "b")
    }

    @Test("A focus request set before layout focuses the matching control")
    func focusStateProgrammatic() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }

        let token = StringBox("b")          // the app asks for "b" up front
        registerFocused(coord, id: "a", token: token)   // auto-focus a, but don't clobber
        registerFocused(coord, id: "b", token: token)   // requested → focus moves here

        #expect(coord.isFocused("b"))
        #expect(token.value == "b")
    }

    @Test("A focused picker cycles with arrows/Space and jumps with digits")
    func pickerControl() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }

        let box = IntBox(0)
        coord.registerPicker(id: "p", selection: Binding(get: { box.value }, set: { box.value = $0 }), count: 3)

        #expect(coord.isFocused("p"))
        _ = coord.handle(.right)              // 0 → 1
        #expect(box.value == 1)
        _ = coord.handle(.character(" "))     // 1 → 2
        #expect(box.value == 2)
        _ = coord.handle(.right)              // 2 → 0 (wraps)
        #expect(box.value == 0)
        _ = coord.handle(.left)               // 0 → 2 (wraps back)
        #expect(box.value == 2)
        _ = coord.handle(.character("1"))     // jump to option 1 (index 0)
        #expect(box.value == 0)
        _ = coord.handle(.character("3"))     // jump to option 3 (index 2)
        #expect(box.value == 2)
    }

    @Test("Escape blurs focus, doesn't silently re-focus, and Tab brings it back")
    func escapeBlurs() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }

        let token = StringBox("")
        registerFocused(coord, id: "a", token: token)
        registerFocused(coord, id: "b", token: token)

        _ = coord.handle(.tab)                 // focus b, written back
        #expect(coord.isFocused("b"))
        #expect(token.value == "b")

        _ = coord.handle(.escape)              // blur
        #expect(coord.focused == nil)
        #expect(token.value == "")             // @FocusState cleared

        // A subsequent render (re-registration) must not silently re-focus.
        registerFocused(coord, id: "a", token: token)
        registerFocused(coord, id: "b", token: token)
        #expect(coord.focused == nil)

        _ = coord.handle(.tab)                 // Tab brings focus back to the first
        #expect(coord.isFocused("a"))
    }

    // MARK: Scroll views (share the same singleton — kept in this serialized suite)

    @Test("Arrow keys move the scroll offset and clamp to the content")
    func scrollKeys() {
        let coord = FocusCoordinator.shared
        coord.reset()
        coord.registerScroll(id: "s", viewportHeight: 4, contentHeight: 10)
        coord.focusNext()   // focus the scroll view
        #expect(coord.scrollOffset(for: "s") == 0)

        _ = coord.handle(.down)
        _ = coord.handle(.down)
        #expect(coord.scrollOffset(for: "s") == 2)

        _ = coord.handle(.up)
        #expect(coord.scrollOffset(for: "s") == 1)

        _ = coord.handle(.end)
        #expect(coord.scrollOffset(for: "s") == 6)   // max = 10 - 4

        _ = coord.handle(.down)   // already at end → stays clamped
        #expect(coord.scrollOffset(for: "s") == 6)

        _ = coord.handle(.home)
        #expect(coord.scrollOffset(for: "s") == 0)
        coord.reset()
    }

    // MARK: Selectable lists

    @Test("Arrows move the list selection and clamp to the row range")
    func listNavigation() {
        let coord = FocusCoordinator.shared
        coord.reset()
        let sel = OptionalIntBox(nil)
        coord.registerList(id: "l", selection: Binding(get: { sel.value }, set: { sel.value = $0 }), count: 5, viewportRows: nil)
        coord.focusNext()

        _ = coord.handle(.down)          // nil → 0
        #expect(sel.value == 0)
        _ = coord.handle(.down)
        #expect(sel.value == 1)
        _ = coord.handle(.up)
        #expect(sel.value == 0)
        _ = coord.handle(.up)            // clamp at 0
        #expect(sel.value == 0)
        _ = coord.handle(.end)
        #expect(sel.value == 4)
        _ = coord.handle(.down)          // clamp at last
        #expect(sel.value == 4)
        coord.reset()
    }

    @Test("A scrolling list's offset follows the selection into view")
    func scrollFollowsSelection() {
        let coord = FocusCoordinator.shared
        coord.reset()
        let sel = OptionalIntBox(0)
        coord.registerList(id: "l", selection: Binding(get: { sel.value }, set: { sel.value = $0 }), count: 10, viewportRows: 3)
        coord.focusNext()
        #expect(coord.listOffset(for: "l") == 0)

        _ = coord.handle(.end)           // select row 9 → offset = 9 - 3 + 1 = 7
        #expect(sel.value == 9)
        #expect(coord.listOffset(for: "l") == 7)

        _ = coord.handle(.home)          // back to top
        #expect(coord.listOffset(for: "l") == 0)
        coord.reset()
    }

    @Test("An editor's scroll offset follows the cursor line minimally")
    func editorOffsetFollowsCursor() {
        let coord = FocusCoordinator.shared
        coord.reset()
        // 20 lines, 6-row viewport.
        // Cursor within the first window → no scroll.
        #expect(coord.editorScrollOffset(id: "e", cursorLine: 3, viewport: 6, totalLines: 20) == 0)
        // Cursor past the bottom → scroll just enough to reveal it.
        #expect(coord.editorScrollOffset(id: "e", cursorLine: 8, viewport: 6, totalLines: 20) == 3)  // 8-6+1
        // Cursor still inside the current window → offset unchanged (minimal).
        #expect(coord.editorScrollOffset(id: "e", cursorLine: 5, viewport: 6, totalLines: 20) == 3)
        // Cursor above the window → scroll up to it.
        #expect(coord.editorScrollOffset(id: "e", cursorLine: 1, viewport: 6, totalLines: 20) == 1)
        // Clamped so the last window doesn't overscroll.
        #expect(coord.editorScrollOffset(id: "e", cursorLine: 19, viewport: 6, totalLines: 20) == 14) // 20-6
        coord.reset()
    }

    @Test("An editor's horizontal offset follows the cursor column minimally")
    func editorHorizontalOffsetFollowsCursor() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }
        // A 30-column longest line (+1 for the end-of-line cursor), 10-column window.
        // Cursor within the first window → no scroll.
        #expect(coord.editorHorizontalOffset(id: "e", cursorColumn: 4, viewport: 10, totalColumns: 31) == 0)
        // Cursor past the right edge → scroll just enough to reveal it.
        #expect(coord.editorHorizontalOffset(id: "e", cursorColumn: 14, viewport: 10, totalColumns: 31) == 5)  // 14-10+1
        // Cursor still inside the current window → offset unchanged (minimal).
        #expect(coord.editorHorizontalOffset(id: "e", cursorColumn: 8, viewport: 10, totalColumns: 31) == 5)
        // Cursor left of the window → scroll back to it.
        #expect(coord.editorHorizontalOffset(id: "e", cursorColumn: 2, viewport: 10, totalColumns: 31) == 2)
        // Clamped so the last window doesn't overscroll.
        #expect(coord.editorHorizontalOffset(id: "e", cursorColumn: 30, viewport: 10, totalColumns: 31) == 21) // 31-10
        // The stored offset is readable without adjusting it.
        #expect(coord.editorHorizontalOffset(for: "e") == 21)
    }

    @Test("A TextEditor line wider than the viewport windows horizontally instead of wrapping")
    func editorLongLineWindowsHorizontally() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }

        let box = StringBox("abcdefghijklmnopqrstuvwxyz")   // 26 columns
        let editor = TextEditor("notes", text: Binding(get: { box.value }, set: { box.value = $0 }))
            .frame(width: 12, alignment: .topLeading)       // gutter (2) + 10 content columns

        // First render registers and focuses the editor.
        _ = editor.renderString()

        // Cursor at the line end → the window shows the tail of the line.
        _ = coord.handle(.end)
        let tail = TextMetrics.stripANSI(editor.renderString())
        #expect(tail.contains("rstuvwxyz"))
        #expect(!tail.contains("abc"))

        // Cursor back at the start → the window slides home again.
        _ = coord.handle(.home)
        let head = TextMetrics.stripANSI(editor.renderString())
        #expect(head.contains("abcdefghij"))
        #expect(!head.contains("xyz"))
    }
}
}

// MARK: - Slider testing

extension ControlSingletonTests {
@Suite("Slider Testing", .serialized)
struct SliderTests {
    @Test("Arrows step the bound value by the step and clamp to the range")
    func sliderKeys() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }

        let box = DoubleBox(50)
        coord.registerSlider(id: "s", value: Binding(get: { box.value }, set: { box.value = $0 }), range: 0...100, step: 10)
        #expect(coord.isFocused("s"))

        _ = coord.handle(.right)
        #expect(box.value == 60)
        _ = coord.handle(.up)
        #expect(box.value == 70)
        _ = coord.handle(.left)
        _ = coord.handle(.down)
        #expect(box.value == 50)

        _ = coord.handle(.end)
        #expect(box.value == 100)
        _ = coord.handle(.right)          // clamped at the maximum
        #expect(box.value == 100)
        _ = coord.handle(.home)
        #expect(box.value == 0)
        _ = coord.handle(.left)           // clamped at the minimum
        #expect(box.value == 0)
    }

    @Test("Slider renders a track with the thumb at the value's fraction")
    func sliderRendersTrack() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }

        let slider = Slider(value: .constant(0.5), width: 11)
        let out = TextMetrics.stripANSI(slider.renderString())
        // 11 columns, fraction 0.5 → 5 filled, the thumb, 5 empty.
        #expect(out.contains("━━━━━●─────"))
    }

    @Test("Tab moves focus past a slider like any other control")
    func sliderFocusRing() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }

        let box = DoubleBox(0)
        coord.registerSlider(id: "s", value: Binding(get: { box.value }, set: { box.value = $0 }), range: 0...1, step: 0.1)
        let text = StringBox("")
        coord.register(id: "f", binding: Binding(get: { text.value }, set: { text.value = $0 }), onSubmit: nil)

        #expect(coord.isFocused("s"))
        _ = coord.handle(.tab)
        #expect(coord.isFocused("f"))
    }
}
}

// MARK: - Navigation testing

extension ControlSingletonTests {
@Suite("Navigation Testing", .serialized)
struct NavigationTests {
    @Test("Inline: a link appends its destination below and disables the old layer")
    func inlinePushAppends() {
        let coord = FocusCoordinator.shared
        coord.reset(); NavigationCoordinator.shared.reset()
        defer { coord.reset(); NavigationCoordinator.shared.reset() }

        let stack = NavigationStack(id: "nav") {
            Text("root-content")
            NavigationLink("Open") { Button("Next") {} }
        }

        let first = TextMetrics.stripANSI(stack.renderString())
        #expect(first.contains("root-content"))
        #expect(first.contains("Open ›"))
        #expect(!first.contains("Next"))
        #expect(coord.isFocused("Open"))

        _ = coord.handle(.enter)   // activate the link → push
        let second = TextMetrics.stripANSI(stack.renderString())
        // The old layer stays visible above the appended destination…
        let root = second.range(of: "root-content")!.lowerBound
        let next = second.range(of: "Next")!.lowerBound
        #expect(root < next)
        // …but its controls are disabled: the new layer's button took focus,
        // and the focus ring contains only the new layer.
        #expect(coord.isFocused("Next"))
        _ = coord.handle(.tab)
        #expect(coord.isFocused("Next"))
    }

    @Test("Full-screen: a link replaces the stack's content with its destination")
    func fullScreenPushReplaces() {
        let coord = FocusCoordinator.shared
        coord.reset(); NavigationCoordinator.shared.reset()
        BodyRenderingStore.shared.fullScreenActive = true
        defer {
            BodyRenderingStore.shared.fullScreenActive = false
            coord.reset(); NavigationCoordinator.shared.reset()
        }

        let stack = NavigationStack(id: "nav-fs") {
            Text("root-content")
            NavigationLink("Open") { Text("detail-content") }
        }

        let first = TextMetrics.stripANSI(stack.renderString())
        #expect(first.contains("root-content"))
        #expect(coord.isFocused("Open"))

        _ = coord.handle(.enter)
        let second = TextMetrics.stripANSI(stack.renderString())
        #expect(second.contains("detail-content"))
        #expect(!second.contains("root-content"))
    }

    @Test("navigationTitle / navigationSubtitle render a title bar above the content")
    func titleBar() {
        let coord = FocusCoordinator.shared
        coord.reset(); NavigationCoordinator.shared.reset()
        defer { coord.reset(); NavigationCoordinator.shared.reset() }

        let stack = NavigationStack(id: "nav-title") {
            Text("hello")
                .navigationTitle("Settings")
                .navigationSubtitle("General")
        }
        let lines = TextMetrics.stripANSI(stack.renderString())
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        #expect(lines[0] == "Settings")
        #expect(lines[1] == "General")
        #expect(lines[2].hasPrefix("─"))
        #expect(lines[3] == "hello")
    }

    @Test("Full-screen: a sidebar link replaces the split view's detail column")
    func splitViewReplacesDetail() {
        let coord = FocusCoordinator.shared
        coord.reset(); NavigationCoordinator.shared.reset()
        BodyRenderingStore.shared.fullScreenActive = true
        defer {
            BodyRenderingStore.shared.fullScreenActive = false
            coord.reset(); NavigationCoordinator.shared.reset()
        }

        let split = NavigationSplitView(id: "split") {
            NavigationLink("General") { Text("general-detail") }
        } detail: {
            Text("placeholder-detail")
        }

        let first = TextMetrics.stripANSI(split.renderString())
        #expect(first.contains("General"))
        #expect(first.contains("placeholder-detail"))
        #expect(first.contains("│"))   // the vertical rule between the columns
        #expect(coord.isFocused("General"))

        _ = coord.handle(.enter)
        let second = TextMetrics.stripANSI(split.renderString())
        #expect(second.contains("general-detail"))
        #expect(!second.contains("placeholder-detail"))
        // The sidebar stays interactive after the push.
        #expect(coord.isFocused("General"))
    }

    @Test("Inline: a sheet appends its card below and swaps focus in and out")
    func sheetInline() {
        let coord = FocusCoordinator.shared
        coord.reset(); SheetPresentationTracker.shared.reset()
        defer { coord.reset(); SheetPresentationTracker.shared.reset() }

        let box = BoolBox(false)
        let view = Group(contents: [
            Text("base-content"),
            Button("OpenSheet") { box.value = true }
        ]).sheet(isPresented: Binding(get: { box.value }, set: { box.value = $0 }), id: "sheet-a") {
            Button("Close") { box.value = false }
        }

        let closed = TextMetrics.stripANSI(view.renderString())
        #expect(closed.contains("base-content"))
        #expect(!closed.contains("Close"))
        #expect(coord.isFocused("OpenSheet"))

        box.value = true
        let open = TextMetrics.stripANSI(view.renderString())
        // The base stays visible above the sheet card…
        let base = open.range(of: "base-content")!.lowerBound
        let close = open.range(of: "Close")!.lowerBound
        #expect(base < close)
        // …but focus moved into the sheet, and only its controls are live.
        #expect(coord.isFocused("Close"))
        _ = coord.handle(.tab)
        #expect(coord.isFocused("Close"))

        // Dismissing restores the base view and its focus.
        box.value = false
        let dismissed = TextMetrics.stripANSI(view.renderString())
        #expect(!dismissed.contains("Close"))
        #expect(coord.isFocused("OpenSheet"))
    }

    @Test("Full-screen: a presented sheet covers the view with its card")
    func sheetFullScreen() {
        let coord = FocusCoordinator.shared
        coord.reset(); SheetPresentationTracker.shared.reset()
        BodyRenderingStore.shared.fullScreenActive = true
        defer {
            BodyRenderingStore.shared.fullScreenActive = false
            coord.reset(); SheetPresentationTracker.shared.reset()
        }

        let box = BoolBox(true)
        let view = Text("base-content")
            .sheet(isPresented: Binding(get: { box.value }, set: { box.value = $0 }), id: "sheet-b") {
                Text("sheet-content")
            }

        let out = TextMetrics.stripANSI(view.renderString())
        #expect(out.contains("sheet-content"))
        #expect(!out.contains("base-content"))
        // The card draws a rounded border around the sheet content.
        #expect(out.contains("╭"))
    }

    @Test("Full-screen: dismiss inside a sheet closes the sheet, not the session")
    func sheetDismissCloses() {
        let coord = FocusCoordinator.shared
        coord.reset(); SheetPresentationTracker.shared.reset()
        BodyRenderingStore.shared.fullScreenActive = true
        defer {
            BodyRenderingStore.shared.fullScreenActive = false
            coord.reset(); SheetPresentationTracker.shared.reset()
        }

        // Reads `\.dismiss` during body evaluation — inside the sheet's
        // environment scope — and captures it into the button's action.
        struct SheetBody: View {
            @Environment(\.dismiss) var dismiss
            var body: some View {
                Button("Done") { [dismiss] in dismiss() }
            }
        }

        let box = BoolBox(false)
        let view = Group(contents: [
            Text("base-content"),
            Button("OpenSheet") { box.value = true }
        ]).sheet(isPresented: Binding(get: { box.value }, set: { box.value = $0 }), id: "sheet-c") {
            SheetBody()
        }

        _ = view.renderString()
        box.value = true
        _ = view.renderString()          // presents; focus lands on "Done"
        #expect(coord.isFocused("Done"))

        _ = coord.handle(.enter)         // dismiss() → closes the sheet…
        #expect(box.value == false)
        // …without requesting the session's exit.
        #expect(!BodyRenderingStore.shared.exitRequested)

        let after = TextMetrics.stripANSI(view.renderString())
        #expect(after.contains("base-content"))
        #expect(!after.contains("Done"))
        #expect(coord.isFocused("OpenSheet"))
    }

    @Test("inspector shows its pane below the content while presented (inline)")
    func inspectorPane() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }

        let box = BoolBox(false)
        let view = Text("main-content")
            .inspector(isPresented: Binding(get: { box.value }, set: { box.value = $0 })) {
                Text("inspector-pane")
            }

        let closed = TextMetrics.stripANSI(view.renderString())
        #expect(closed.contains("main-content"))
        #expect(!closed.contains("inspector-pane"))

        box.value = true
        let open = TextMetrics.stripANSI(view.renderString())
        let main = open.range(of: "main-content")!.lowerBound
        let pane = open.range(of: "inspector-pane")!.lowerBound
        #expect(main < pane)
    }
}
}

// MARK: - Button testing

/// Routing tests drive the process-wide ``FocusCoordinator/shared`` singleton,
/// so they must not run in parallel with one another.
extension ControlSingletonTests {
@Suite("Button Testing", .serialized)
struct ButtonTests {
    private func plain(_ v: some View) -> String {
        TextMetrics.stripANSI(v.renderString())
    }
    private func config(focused: Bool, label: String = "OK", role: ButtonRole? = nil) -> ButtonStyleConfiguration {
        ButtonStyleConfiguration(label: AnyView(Text(label)), role: role, isFocused: focused)
    }

    @Test("A focused button fires its action on Return and on Space")
    func buttonActivation() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }

        let pressed = StringBox("")
        coord.registerButton(id: "b", action: { pressed.value += "!" })

        #expect(coord.isFocused("b"))          // first control auto-focuses
        #expect(coord.handle(.enter))
        #expect(coord.handle(.character(" ")))
        #expect(pressed.value == "!!")
    }

    @Test("An unfocused button does not fire; Tab reaches it first")
    func buttonFocusRing() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }

        let pressed = StringBox("")
        coord.registerButton(id: "first", action: { pressed.value += "1" })
        coord.registerButton(id: "second", action: { pressed.value += "2" })

        _ = coord.handle(.enter)               // fires "first" (auto-focused)
        _ = coord.handle(.tab)                 // move to "second"
        _ = coord.handle(.enter)
        #expect(pressed.value == "12")
    }

    @Test("The default style brackets the label and marks focus")
    func defaultStyle() {
        let blurred = plain(DefaultButtonStyle().makeBody(configuration: config(focused: false)))
        let focused = plain(DefaultButtonStyle().makeBody(configuration: config(focused: true)))
        #expect(blurred.contains("[ OK ]"))
        #expect(focused.contains("> [ OK ]"))
    }

    @Test("The bordered style draws a box around the label")
    func borderedStyle() {
        let out = plain(BorderedButtonStyle().makeBody(configuration: config(focused: false)))
        #expect(out.contains("OK"))
        #expect(out.contains("╭"))
        #expect(out.contains("╯"))
    }

    @Test("The plain style shows only the label but still reflects focus")
    func plainStyle() {
        let blurred = PlainButtonStyle().makeBody(configuration: config(focused: false))
        let focused = PlainButtonStyle().makeBody(configuration: config(focused: true))
        #expect(plain(blurred) == "OK")
        #expect(blurred.renderString() != focused.renderString())
    }

    @Test("Button lowers through its style and shows the title")
    func buttonRendersLabel() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }

        let out = TextMetrics.stripANSI(Button("Save") {}.renderString())
        #expect(out.contains("[ Save ]"))
    }

    @Test("A destructive role changes the rendered styling in every built-in style")
    func destructiveRole() {
        #expect(DefaultButtonStyle().makeBody(configuration: config(focused: false)).renderString()
                != DefaultButtonStyle().makeBody(configuration: config(focused: false, role: .destructive)).renderString())
        #expect(PlainButtonStyle().makeBody(configuration: config(focused: false)).renderString()
                != PlainButtonStyle().makeBody(configuration: config(focused: false, role: .destructive)).renderString())
        #expect(BorderedButtonStyle().makeBody(configuration: config(focused: false)).renderString()
                != BorderedButtonStyle().makeBody(configuration: config(focused: false, role: .destructive)).renderString())
    }
}
}

// MARK: - Button-composed views (Stepper, Menu, Link)

/// These tests drive the process-wide ``FocusCoordinator/shared`` singleton,
/// so they must not run in parallel with one another.
extension ControlSingletonTests {
@Suite("Button Composition Testing", .serialized)
struct ButtonCompositionTests {
    private func plain(_ v: some View) -> String {
        TextMetrics.stripANSI(v.renderString())
    }

    @Test("Stepper renders label, buttons, and the current value")
    func stepperRenders() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }

        let value = IntBox(3)
        let stepper = Stepper("Qty", value: Binding(get: { value.value }, set: { value.value = $0 }))
        let out = plain(stepper)
        #expect(out.contains("Qty"))
        #expect(out.contains("[-]"))
        #expect(out.contains("3"))
        #expect(out.contains("[+]"))
    }

    @Test("Stepper's buttons step the bound value and clamp to the bounds")
    func stepperSteps() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }

        let value = IntBox(1)
        let stepper = Stepper("Qty", value: Binding(get: { value.value }, set: { value.value = $0 }), in: 1...3)
        _ = stepper.renderString()          // lowers → registers [-] then [+]

        #expect(coord.isFocused("Qty.decrement"))
        _ = coord.handle(.enter)            // 1 → clamped at lower bound
        #expect(value.value == 1)
        _ = coord.handle(.tab)              // focus [+]
        _ = coord.handle(.enter)
        _ = coord.handle(.enter)
        _ = coord.handle(.enter)            // 1 → 2 → 3 → clamped
        #expect(value.value == 3)
    }

    @Test("Menu renders its title above indented items")
    func menuLayout() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }

        let menu = Menu("File") {
            Button("New") {}
            Button("Open") {}
        }
        let lines = plain(menu).components(separatedBy: "\n")
        #expect(lines[0] == "File")
        #expect(lines.count == 3)
        #expect(lines[1].hasPrefix("  "))
        #expect(lines[1].contains("New"))
        #expect(lines[2].contains("Open"))
    }

    @Test("A static Link render stays plain and registers no control")
    func linkStatic() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }

        let out = Link("Apple", destination: "https://apple.com").renderString()
        #expect(TextMetrics.stripANSI(out) == "Apple")
        #expect(coord.focused == nil)
    }

    @Test("Inside a rendering session a Link joins the focus ring and opens on Return")
    func linkActivation() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }
        let store = BodyRenderingStore.shared
        store.sessionActive = true
        defer { store.sessionActive = false }

        let opened = StringBox("")
        let original = LinkOpener.handler
        LinkOpener.handler = { opened.value = $0 }
        defer { LinkOpener.handler = original }

        _ = Link("Apple", destination: "https://apple.com").renderString()
        #expect(coord.focused != nil)       // auto-focused as the first control
        _ = coord.handle(.enter)
        #expect(opened.value == "https://apple.com")
    }
}
}

// MARK: - print() capture during rendering sessions

/// These tests redirect the process-wide `stdout` and the shared
/// ``TerminalOutput`` descriptor, so they must not run in parallel with other
/// singleton-driven tests.
extension ControlSingletonTests {
@Suite("Session Print Capture Testing", .serialized)
struct SessionPrintCaptureTests {

    @Test("print() during a capture session is delivered line-by-line to the handler")
    func captureRoutesPrints() {
        let captured = StringBox("")
        #expect(SessionPrintCapture.shared.start { captured.value += $0 })
        print("hello")
        print("world")
        SessionPrintCapture.shared.stop()   // waits for the drain to finish
        #expect(captured.value.contains("hello\n"))
        #expect(captured.value.contains("world\n"))
    }

    @Test("A print without a trailing newline is still delivered on stop")
    func capturePartialLine() {
        let captured = StringBox("")
        #expect(SessionPrintCapture.shared.start { captured.value += $0 })
        print("no newline", terminator: "")
        SessionPrintCaptureTestsSupport.flushStdout()
        SessionPrintCapture.shared.stop()
        #expect(captured.value.contains("no newline\n"))
    }

    @Test("An inline body taller than the terminal is clamped to the visible rows")
    func inlineBodyClampedToScreen() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("swiftli-inline-clamp-\(getpid()).txt")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        defer { try? FileManager.default.removeItem(at: url) }
        let file = try FileHandle(forWritingTo: url)

        let originalFD = TerminalOutput.fd
        TerminalOutput.fd = file.fileDescriptor
        defer { TerminalOutput.fd = originalFD }

        let rows = TerminalSize.current.rows
        let lines: [any View] = (0..<(rows * 2)).map { Text("line \($0)") }
        let renderer = InlineRenderer()
        renderer.render(VStack(alignment: .leading, spacing: 0, children: lines))
        renderer.finalize()

        TerminalOutput.fd = originalFD
        try file.close()
        let output = try String(contentsOf: url, encoding: .utf8)

        // The first render emits one "\n" per body line; the body must fit
        // the screen minus the parked-cursor row, or cursor-relative repaints
        // would no longer reach its first line.
        let emitted = output.filter { $0 == "\n" }.count
        #expect(emitted == rows - 1)
    }

    @Test("runBody(while:) opens the session around the work and tears it down after")
    func runBodyLifecycle() async throws {
        struct Fixture: InlineCommand {
            var body: some View { EmptyView() }
        }

        await Fixture().runBody {
            #expect(BodyRenderingStore.shared.sessionActive)
        }
        #expect(!BodyRenderingStore.shared.sessionActive)
    }

    @Test("FullScreenCommand's default run() keeps the session live until exit is requested")
    func defaultRunLifecycle() async throws {
        struct Fixture: FullScreenCommand {
            // No run() — the default implementation drives the session.
            var body: some View { EmptyView() }
        }

        let session = Task {
            try await Fixture().run()
        }
        // Wait (bounded) for the session to open, then quit as Ctrl-C would.
        var waited = 0
        while !BodyRenderingStore.shared.sessionActive && waited < 200 {
            try await Task.sleep(nanoseconds: 10_000_000)
            waited += 1
        }
        #expect(BodyRenderingStore.shared.sessionActive)
        BodyRenderingStore.shared.requestExit()
        try await session.value
        #expect(!BodyRenderingStore.shared.sessionActive)
    }

    @Test("An idle full-screen body lingers for a reading pause, then ends by itself")
    func fullScreenIdleLingers() async throws {
        struct Fixture: FullScreenCommand {
            // Static content: no controls, no task, no driver.
            var body: some View { Text("static") }
        }

        BodyRenderingStore.shared.resetExit()
        let start = Date()
        try await Fixture().run()   // must return without any exit request
        let elapsed = Date().timeIntervalSince(start)
        #expect(!BodyRenderingStore.shared.sessionActive)
        #expect(elapsed >= 1.5)     // stayed visible for the reading pause…
        #expect(elapsed < 8)        // …but did not wait for Ctrl-C
    }

    @Test("A scene modifier applies at the outermost level: readingPause(0) skips the idle linger")
    func sceneModifierOverridesReadingPause() async throws {
        struct Fixture: FullScreenCommand {
            var body: some Scene {
                // The modifier returns a Scene (not a View): the body is the
                // one scene expression SceneBuilder accepts.
                Text("static").readingPause(0)
            }
        }

        BodyRenderingStore.shared.resetExit()
        let start = Date()
        try await Fixture().run()
        let elapsed = Date().timeIntervalSince(start)
        #expect(!BodyRenderingStore.shared.sessionActive)
        #expect(elapsed < 1.5)      // the default linger would be at least 2 s
    }

    @Test("DismissAction requests the session exit that the run loops poll")
    func dismissRequestsExit() {
        BodyRenderingStore.shared.resetExit()
        let dismiss = DismissAction()
        dismiss()
        #expect(BodyRenderingStore.shared.exitRequested)
        BodyRenderingStore.shared.resetExit()
    }

    @Test("body + task + dismiss: an inline command with no run() exits by itself")
    func dismissEndsDefaultRun() async throws {
        struct Fixture: InlineCommand {
            @Environment(\.dismiss) private var dismiss

            // No run() — the default implementation drives the session, and
            // the task dismisses it when the work is done.
            var body: some View {
                EmptyView().task { [dismiss] in
                    try? await Task.sleep(nanoseconds: 30_000_000)
                    dismiss()
                }
            }
        }

        try await Fixture().run()
        #expect(!BodyRenderingStore.shared.sessionActive)
    }

    @Test("A command's content embedded via body renders in the parent command's mode")
    func nestedCommandFollowsParentMode() async throws {
        struct FullScreenChild: FullScreenCommand {
            var body: some View { Text("child-content") }
        }
        struct InlineParent: InlineCommand {
            var body: some View {
                Text("parent")
                FullScreenChild().body   // a command's content embeds as a view
            }
        }

        // The child's body flows into the parent's frame like any other view.
        let out = TextMetrics.stripANSI(InlineParent().body.renderString())
        #expect(out.contains("parent"))
        #expect(out.contains("child-content"))

        // The session mode is the parent's: inline, no alternate screen.
        let parent = InlineParent()
        parent.startBodyRendering()
        #expect(BodyRenderingStore.shared.sessionActive)
        #expect(!BodyRenderingStore.shared.fullScreenActive)
        parent.stopBodyRendering()
    }

    @Test("A nested command's session primitives join the parent session without switching its mode")
    func nestedSessionInheritsMode() async throws {
        struct FullScreenChild: FullScreenCommand {
            var body: some View { Text("child") }
        }
        struct InlineParent: InlineCommand {
            var body: some View { Text("parent") }
        }

        let parent = InlineParent()
        parent.startBodyRendering()
        #expect(BodyRenderingStore.shared.sessionActive)
        #expect(!BodyRenderingStore.shared.fullScreenActive)

        // The child's own start joins the running session: the mode stays
        // inline — it does not switch to the alternate screen.
        let child = FullScreenChild()
        child.startBodyRendering()
        #expect(BodyRenderingStore.shared.sessionActive)
        #expect(!BodyRenderingStore.shared.fullScreenActive)

        // The child's stop leaves the parent's session running…
        child.stopBodyRendering()
        #expect(BodyRenderingStore.shared.sessionActive)

        // …and only the parent's stop tears the session down.
        parent.stopBodyRendering()
        #expect(!BodyRenderingStore.shared.sessionActive)
    }

    @Test("Idle exit: a static inline body renders once and the session ends by itself")
    func idleExitStatic() async throws {
        struct Fixture: InlineCommand {
            var body: some View { Text("done") }
        }

        try await Fixture().run()   // must return without any exit request
        #expect(!BodyRenderingStore.shared.sessionActive)
    }

    @Test("Idle exit: a task keeps the session alive and its completion ends it")
    func idleExitAfterTask() async throws {
        struct Fixture: InlineCommand {
            var finished = BoolBox(false)
            // Nothing to decode from arguments; the box is test plumbing.
            private enum CodingKeys: CodingKey {}
            var body: some View {
                EmptyView().task {
                    try? await Task.sleep(nanoseconds: 120_000_000)
                    finished.value = true
                }
            }
        }

        let finished = BoolBox(false)
        try await Fixture(finished: finished).run()
        #expect(finished.value)   // the session outlived the whole task
        #expect(!BodyRenderingStore.shared.sessionActive)
    }

    @Test("Idle exit: a visible control keeps the session alive until it is hidden")
    func idleExitWhenControlsHidden() async throws {
        struct Fixture: InlineCommand {
            @State var show = true
            var body: some View {
                if show {
                    Toggle("t", isOn: .constant(false))
                } else {
                    Text("done")
                }
            }
        }

        let fixture = Fixture()
        let session = Task { try await fixture.run() }

        var waited = 0
        while !BodyRenderingStore.shared.sessionActive && waited < 200 {
            try await Task.sleep(nanoseconds: 10_000_000)
            waited += 1
        }
        // The toggle is on screen: the session must survive several idle polls.
        try await Task.sleep(nanoseconds: 200_000_000)
        #expect(BodyRenderingStore.shared.sessionActive)

        fixture.show = false   // the confirming state change hides the control
        try await session.value
        #expect(!BodyRenderingStore.shared.sessionActive)
    }

    @Test("Idle exit: an active redraw driver keeps the session alive")
    func idleExitWhenDriverStops() async throws {
        struct Fixture: InlineCommand {
            var body: some View { Text("clock") }
        }

        SessionLifecycle.shared.driverBegan()
        let session = Task { try await Fixture().run() }

        try await Task.sleep(nanoseconds: 200_000_000)
        #expect(BodyRenderingStore.shared.sessionActive)

        SessionLifecycle.shared.driverEnded()
        try await session.value
        #expect(!BodyRenderingStore.shared.sessionActive)
    }

    @Test(".task starts once per session and is cancelled at teardown")
    func taskLifecycle() async throws {
        struct Fixture: InlineCommand {
            var starts = IntBox(0)
            var cancelled = BoolBox(false)
            // Nothing to decode from arguments; the boxes are test plumbing.
            private enum CodingKeys: CodingKey {}
            var body: some View {
                EmptyView().task {
                    starts.value += 1
                    do {
                        try await Task.sleep(nanoseconds: 10_000_000_000)
                    } catch {
                        cancelled.value = true
                    }
                }
            }
        }

        let starts = IntBox(0)
        let cancelled = BoolBox(false)
        let fixture = Fixture(starts: starts, cancelled: cancelled)

        await fixture.runBody {
            // Extra render passes must not start extra tasks.
            fixture.updateBody()
            fixture.updateBody()
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        // Teardown cancels the sleeping task; give cancellation a moment.
        var waited = 0
        while !cancelled.value && waited < 100 {
            try await Task.sleep(nanoseconds: 10_000_000)
            waited += 1
        }
        #expect(starts.value == 1)
        #expect(cancelled.value)
    }

    @Test(".task does not start outside a rendering session")
    func taskInertWhenStatic() async throws {
        let starts = IntBox(0)
        let view = EmptyView().task { starts.value += 1 }
        _ = view.renderString()
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(starts.value == 0)
    }

    @Test("onAppear fires once per session even across re-renders")
    func onAppearOncePerSession() async throws {
        struct Fixture: InlineCommand {
            var count = IntBox(0)
            // Nothing to decode from arguments; the box is test plumbing.
            private enum CodingKeys: CodingKey {}
            var body: some View {
                EmptyView().onAppear { count.value += 1 }
            }
        }

        let count = IntBox(0)
        let fixture = Fixture(count: count)
        await fixture.runBody {
            fixture.updateBody()
            fixture.updateBody()
        }
        #expect(count.value == 1)

        // A fresh session fires it again.
        await fixture.runBody {}
        #expect(count.value == 2)
    }

    @Test("task(id:) keeps the task for an unchanged id and restarts on change")
    func taskIdRestart() async throws {
        let starts = IntBox(0)
        let cancelled = BoolBox(false)
        let key = LifecycleKey(fileID: "test", line: 1, column: 1)
        let action: @Sendable () async -> Void = {
            starts.value += 1
            do {
                try await Task.sleep(nanoseconds: 10_000_000_000)
            } catch {
                cancelled.value = true
            }
        }

        SessionLifecycle.shared.startTask(key: key, id: 1, priority: .userInitiated, action: action)
        SessionLifecycle.shared.startTask(key: key, id: 1, priority: .userInitiated, action: action)
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(starts.value == 1)   // same id → second call is a no-op

        SessionLifecycle.shared.startTask(key: key, id: 2, priority: .userInitiated, action: action)
        var waited = 0
        while (!cancelled.value || starts.value < 2) && waited < 100 {
            try await Task.sleep(nanoseconds: 10_000_000)
            waited += 1
        }
        #expect(starts.value == 2)   // new id → previous cancelled, new started
        #expect(cancelled.value)
        SessionLifecycle.shared.reset()
    }

    @Test("A session buffers captured prints for replay after it ends")
    func sessionBuffersPrints() {
        let store = BodyRenderingStore.shared
        _ = store.drainCapturedLog()        // start from a clean buffer
        store.appendCapturedLog("first\n")
        store.appendCapturedLog("second\n")
        #expect(store.drainCapturedLog() == ["first\n", "second\n"])
        #expect(store.drainCapturedLog().isEmpty)
    }
}
}

/// Test-only helper: `fflush` is variadic-adjacent C API that reads more
/// clearly behind a name.
private enum SessionPrintCaptureTestsSupport {
    static func flushStdout() {
        fflush(stdout)
    }
}

#endif
