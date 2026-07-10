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
        coord.registerToggle(id: "t", isOn: Binding(get: { box.value }, set: { box.value = $0 }), onSubmit: nil)

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
        coord.registerPicker(id: "p", selection: Binding(get: { box.value }, set: { box.value = $0 }), count: 3, onSubmit: nil)

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
        coord.registerScroll(id: "s", viewportHeight: 4, contentHeight: 10, onSubmit: nil)
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
        coord.registerList(id: "l", selection: Binding(get: { sel.value }, set: { sel.value = $0 }), count: 5, viewportRows: nil, onSubmit: nil)
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
        coord.registerList(id: "l", selection: Binding(get: { sel.value }, set: { sel.value = $0 }), count: 10, viewportRows: 3, onSubmit: nil)
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
