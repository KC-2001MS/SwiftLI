//
//  AppFeatureTests.swift
//  SwiftLITests
//
//  Created by Keisuke Chinone on 2026/11/08.
//
//  Covers what a full-screen keyboard-driven app needs from the library:
//  text that wraps (with mixed styles), styles on composite views, lifecycle
//  keyed by structural identity, lists that follow a multi-line selection,
//  typed navigation paths, tabs that keep their state, overlays, alerts,
//  and the focus ring rebuilt every frame.

#if swift(>=6.0)
import Testing
@_spi(RenderingInternals) @testable import SwiftLI
import Foundation

// MARK: - Helpers

/// Counts calls from closures that must stay `Sendable`.
private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = 0
    var value: Int { lock.lock(); defer { lock.unlock() }; return _value }
    func increment() { lock.lock(); _value += 1; lock.unlock() }
}

/// Hands a child view's `$count` binding out to the test.
private final class BindingProbe<Value: Sendable>: @unchecked Sendable {
    var binding: Binding<Value>?
}

/// A child view with `@State` of its own.
private struct StatefulCounter: View {
    @State private var count = 0
    let label: String
    let probe: BindingProbe<Int>

    init(label: String, probe: BindingProbe<Int>) {
        self.label = label
        self.probe = probe
    }

    var body: some View {
        let _ = { probe.binding = $count }()
        Text("\(label)=\(count)")
    }
}

/// A composite view with no style storage of its own.
private struct PlainRow: View {
    var body: some View { Text("row") }
}

private struct Entry: Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
}

private enum Route: Hashable, Sendable {
    case detail(Int)
}

private final class PathDismissBox: @unchecked Sendable {
    var action: DismissAction?
}

private struct DetailPage: View {
    @Environment(\.dismiss) private var dismiss
    let id: Int
    let box: PathDismissBox
    var body: some View {
        let _ = { box.action = dismiss }()
        Text("detail-\(id)")
    }
}

private final class ProxyBox: @unchecked Sendable {
    var proxy: ScrollViewProxy?
}

private func waitUntil(timeout: TimeInterval = 1.0, _ condition: () -> Bool) async throws {
    let deadline = ProcessInfo.processInfo.systemUptime + timeout
    while !condition() && ProcessInfo.processInfo.systemUptime < deadline {
        try await Task.sleep(nanoseconds: 10_000_000)
    }
}

/// One frame of a session: the pass is bracketed so controls register and
/// the ring is rebuilt, the view keeps `tree` between frames, and the root is
/// proposed `width` columns in a `height`-row terminal.
private func sessionLines(_ view: any View, tree: RetainedTree, width: Int = 40, height: Int = 24) -> [String] {
    FocusCoordinator.shared.beginRenderPass()
    let lines = RenderPassContext.withPass(retaining: tree) {
        var environment = EnvironmentValues()
        environment.maxWidth = width
        environment.maxHeight = height
        return EnvironmentStack.with(environment) {
            NodeLayout.frame(of: view.lowered(at: 0), proposedWidth: width).lines.map { TextMetrics.stripANSI($0) }
        }
    }
    FocusCoordinator.shared.endRenderPass()
    return lines
}

/// A one-shot frame with a width proposal, outside any session.
private func wrappedLines(_ view: any View, width: Int) -> [String] {
    NodeLayout.frame(of: view.makeNode(), proposedWidth: width).lines.map { TextMetrics.stripANSI($0) }
}

// MARK: - Text

@Suite("Wrapping and multi-style text")
struct WrappingTextTests {
    @Test("Text wraps to the width proposed at the root, as the session renderers propose it")
    func rootProposalWraps() {
        let lines = wrappedLines(VStack { Text("one two three four five six") }, width: 10)
        #expect(lines.count > 1)
        #expect(lines.allSatisfy { TextMetrics.visibleWidth($0) <= 10 })
        #expect(lines.joined(separator: " ") == "one two three four five six")
        // Without a proposal the line stays whole, as before.
        #expect(Text("one two three four five six").renderString().contains("one two three four five six"))
    }

    @Test("An AttributedString text keeps its run styles across a wrap")
    func attributedWraps() {
        var summary = AttributedString("aaaa bbbb cccc")
        let range = summary.range(of: "bbbb cccc")!
        summary[range].foregroundColor = .orange
        summary[range].fontWeight = .bold
        let text = Text(summary)
        guard case .text(_, let contents) = text.makeNode() else { Issue.record("expected a text node"); return }
        let lines = NodeLayout.visualLines(of: contents, proposedWidth: 9, lineLimit: nil)
        #expect(lines.map { TextMetrics.stripANSI($0) } == ["aaaa bbbb", "cccc"])
        // The continuation line re-opens the orange, bold style.
        #expect(lines[1].contains("\u{001B}[38;5;208m"))
        #expect(lines[1].contains("\u{001B}[1m"))
        // Measured size agrees with the wrapped lines.
        #expect(NodeLayout.measure(text.makeNode(), proposedWidth: 9) == Size(width: 9, height: 2))
    }

    @Test("Text + Text concatenates with each side's style and wraps as one")
    func concatenation() {
        let text = Text("★ ").foregroundStyle(.yellow) + Text("42").bold() + Text(" stars")
        let raw = text.renderString()
        #expect(TextMetrics.stripANSI(raw) == "★ 42 stars")
        #expect(raw.contains("\u{001B}[33m"))
        #expect(raw.contains("\u{001B}[1m"))
        let lines = wrappedLines(text, width: 5)
        #expect(lines == ["★ 42", "stars"])
    }

    @Test("Text(_:style:) and Text(_:format:) render formatted values")
    func dateAndFormat() {
        // Locale-dependent wording: check the shape, not the words.
        let relative = TextMetrics.stripANSI(Text(Date().addingTimeInterval(-3 * 3600), style: .relative).renderString())
        #expect(relative.contains("3"))
        let timer = TextMetrics.stripANSI(Text(Date().addingTimeInterval(-62), style: .timer).renderString())
        #expect(timer.hasPrefix("1:0"))
        let compact = TextMetrics.stripANSI(Text(12_300, format: .number.notation(.compactName)).renderString())
        #expect(compact != "12300" && compact.count < 6)
        #expect(TextMetrics.stripANSI(Text(0.5, format: .percent).renderString()).contains("50"))
    }

    @Test("truncationMode and multilineTextAlignment shape wrapped text")
    func truncationAndAlignment() {
        #expect(wrappedLines(Text("abcdefghij").lineLimit(1).truncationMode(.head), width: 5) == ["…ghij"])
        #expect(wrappedLines(Text("abcdefghij").lineLimit(1).truncationMode(.middle), width: 5) == ["ab…ij"])
        #expect(wrappedLines(Text("abcdefghij").lineLimit(1), width: 5) == ["abcd…"])
        #expect(wrappedLines(Text("a\nbbb").multilineTextAlignment(.trailing), width: 10) == ["  a", "bbb"])
        #expect(wrappedLines(Text("a\nbbb").multilineTextAlignment(.center), width: 10) == [" a", "bbb"])
    }
}

// MARK: - Styles on composite views

@Suite("Styles reach composite views")
struct CompositeStyleTests {
    @Test("A style modifier on a custom view cascades onto its content")
    func customView() {
        #expect(PlainRow().foregroundStyle(.red).renderString().contains("\u{001B}[31m"))
        #expect(PlainRow().bold().renderString().contains("\u{001B}[1m"))
        // After a layout modifier, and on a builder group of composites.
        #expect(PlainRow().padding(1).foregroundStyle(.green).renderString().contains("\u{001B}[32m"))
        #expect(VStack { PlainRow(); PlainRow() }.foregroundStyle(.cyan).renderString().contains("\u{001B}[36m"))
        #expect(Group { PlainRow() }.underline().renderString().contains("\u{001B}[4m"))
    }

    @Test("The content's own style still wins over a cascaded one")
    func innerWins() {
        struct ColoredRow: View { var body: some View { Text("row").foregroundStyle(.red) } }
        let raw = ColoredRow().foregroundStyle(.blue).renderString()
        #expect(raw.contains("\u{001B}[31m"))
        #expect(!raw.contains("\u{001B}[34m"))
    }
}

// MARK: - Identity and lifecycle (shared singletons → serialized)

extension ControlSingletonTests {
@Suite("Identity and lifecycle", .serialized)
struct IdentityLifecycleTests {
    @Test("ForEach over Identifiable data keys row state by id, so it follows a reorder")
    func forEachIdentity() {
        let tree = RetainedTree()
        let probes = [BindingProbe<Int>(), BindingProbe<Int>()]
        func view(_ entries: [Entry]) -> any View {
            VStack {
                ForEach(entries) { entry in StatefulCounter(label: entry.title, probe: probes[entry.id]) }
            }
        }
        let a = Entry(id: 0, title: "a"), b = Entry(id: 1, title: "b")
        #expect(sessionLines(view([a, b]), tree: tree) == ["a=0", "b=0"])
        probes[1].binding?.wrappedValue = 7
        #expect(sessionLines(view([a, b]), tree: tree) == ["a=0", "b=7"])
        // Reordered: the state travels with the element, not the position.
        #expect(sessionLines(view([b, a]), tree: tree) == ["b=7", "a=0"])
    }

    @Test("task runs once per ForEach row and is cancelled when the row leaves")
    func perRowTasks() async throws {
        let store = BodyRenderingStore.shared
        let lifecycle = SessionLifecycle.shared
        lifecycle.reset(); store.sessionActive = true
        defer { lifecycle.reset(); store.sessionActive = false }
        let tree = RetainedTree()
        let starts = Counter()
        let cancelled = Counter()
        func view(_ count: Int) -> any View {
            VStack {
                ForEach(0..<count) { i in
                    Text("row \(i)").task {
                        starts.increment()
                        do { try await Task.sleep(nanoseconds: 5_000_000_000) } catch { cancelled.increment() }
                    }
                }
            }
        }
        _ = sessionLines(view(3), tree: tree)
        try await waitUntil { starts.value == 3 }
        #expect(starts.value == 3)
        _ = sessionLines(view(3), tree: tree)
        try await Task.sleep(nanoseconds: 30_000_000)
        #expect(starts.value == 3)          // a re-render starts nothing new
        _ = sessionLines(view(2), tree: tree)
        try await waitUntil { cancelled.value == 1 }
        #expect(cancelled.value == 1)       // the vanished row's task was cancelled
        #expect(starts.value == 3)
    }

    @Test("onAppear re-arms, onDisappear fires, and onChange reports old and new values")
    func appearDisappearChange() async throws {
        let lifecycle = SessionLifecycle.shared
        lifecycle.reset()
        defer { lifecycle.reset() }
        let tree = RetainedTree()
        let appeared = Counter(), disappeared = Counter()
        let changes = Changes()
        func view(show: Bool, value: Int) -> any View {
            VStack {
                if show {
                    Text("shown").onAppear { appeared.increment() }.onDisappear { disappeared.increment() }
                }
                Text("value").onChange(of: value) { old, new in changes.record(old, new) }
            }
        }
        _ = sessionLines(view(show: true, value: 1), tree: tree)
        _ = sessionLines(view(show: true, value: 1), tree: tree)
        #expect(appeared.value == 1)
        _ = sessionLines(view(show: false, value: 2), tree: tree)
        try await waitUntil { disappeared.value == 1 && changes.pairs.count == 1 }
        #expect(disappeared.value == 1)
        #expect(changes.pairs.first?.0 == 1 && changes.pairs.first?.1 == 2)
        _ = sessionLines(view(show: true, value: 2), tree: tree)
        #expect(appeared.value == 2)        // back on screen: onAppear fires again
    }

    final class Changes: @unchecked Sendable {
        private let lock = NSLock()
        private var _pairs: [(Int, Int)] = []
        var pairs: [(Int, Int)] { lock.lock(); defer { lock.unlock() }; return _pairs }
        func record(_ old: Int, _ new: Int) { lock.lock(); _pairs.append((old, new)); lock.unlock() }
    }

    @Test("State writes in one turn coalesce into a single render")
    func coalescedRender() async throws {
        let renders = Counter()
        StateObserverRegistry.shared.register { renders.increment() }
        defer { StateObserverRegistry.shared.unregister() }
        let a = State(wrappedValue: 0), b = State(wrappedValue: 0), c = State(wrappedValue: 0)
        a.wrappedValue = 1; b.wrappedValue = 2; c.wrappedValue = 3
        #expect(renders.value == 0)         // nothing is drawn mid-turn
        try await waitUntil { renders.value >= 1 }
        try await Task.sleep(nanoseconds: 60_000_000)
        #expect(renders.value == 1)
    }

    @Test("Controls with the same label get distinct identities inside a session")
    func automaticControlIDs() {
        let coord = FocusCoordinator.shared
        coord.reset(); defer { coord.reset() }
        let tree = RetainedTree()
        let view = VStack { Button("Save") {}; Button("Save") {} }
        _ = sessionLines(view, tree: tree)
        let first = coord.focused
        #expect(first?.hasPrefix("Save") == true)
        _ = coord.handle(.tab)
        #expect(coord.focused != first)
        #expect(coord.focused?.hasPrefix("Save") == true)
        // Outside a session the label stays the identity.
        _ = Button("Save") {}.renderString()
        #expect(coord.isFocused("Save"))
    }

    @Test("A control that leaves the frame leaves the focus ring; focus moves on")
    func focusRingRebuilt() {
        let coord = FocusCoordinator.shared
        coord.reset(); defer { coord.reset() }
        let tree = RetainedTree()
        let hiddenFired = Counter()
        func view(show: Bool) -> any View {
            VStack {
                if show { Button("Hidden") { hiddenFired.increment() } }
                Button("Other") {}
            }
        }
        _ = sessionLines(view(show: true), tree: tree)
        #expect(coord.focused?.hasPrefix("Hidden") == true)
        _ = sessionLines(view(show: false), tree: tree)
        #expect(coord.focused?.hasPrefix("Other") == true)
        _ = coord.handle(.enter)
        #expect(hiddenFired.value == 0)
    }
}
}

// MARK: - List

extension ControlSingletonTests {
@Suite("List with id selection and multi-line rows", .serialized)
struct ListSelectionTests {
    fileprivate let entries = (1...8).map { Entry(id: $0 * 10, title: "Item \($0)") }

    private func list(selection: Binding<Int?>, submitted: Counter? = nil, reached: Counter? = nil) -> any View {
        List(entries, selection: selection) { entry in
            VStack(alignment: .leading, spacing: 0) {
                Text(entry.title).bold()
                Text("\(entry.title) line 2")
                Text("\(entry.title) line 3")
            }
        }
        .onReachEnd(within: 1) { reached?.increment() }
        .onSubmit { submitted?.increment() }
        .frame(height: 7)
    }

    @Test("Selection is bound by id and the whole selected row is kept in view")
    func idSelectionFollows() {
        let coord = FocusCoordinator.shared
        coord.reset(); defer { coord.reset() }
        let tree = RetainedTree()
        let selected = OptionalIntBox(50)   // "Item 5": rows 12..<15 of 24
        let binding = Binding<Int?>(get: { selected.value }, set: { selected.value = $0 })

        var lines = sessionLines(list(selection: binding), tree: tree)
        #expect(lines.count == 7)
        #expect(lines.contains { $0.contains("Item 5 line 3") })
        #expect(lines.contains { $0.contains("❯ Item 5") })
        #expect(!lines.contains { $0.contains("Item 1") })

        // Down moves the selection by id and the viewport follows it.
        _ = coord.handle(.down)
        #expect(selected.value == 60)
        lines = sessionLines(list(selection: binding), tree: tree)
        #expect(lines.contains { $0.contains("Item 6 line 3") })
        #expect(lines.contains { $0.contains("❯ Item 6") })

        // Page Down moves a screenful of rows; Home returns to the top.
        _ = coord.handle(.pageDown)
        #expect(selected.value == 80)
        _ = coord.handle(.home)
        #expect(selected.value == 10)
        lines = sessionLines(list(selection: binding), tree: tree)
        #expect(lines.first?.contains("Item 1") == true)
    }

    @Test("Return calls the enclosing onSubmit; nearing the end fires onReachEnd once per count")
    func submitAndReachEnd() async throws {
        let coord = FocusCoordinator.shared
        coord.reset(); defer { coord.reset() }
        let tree = RetainedTree()
        let selected = OptionalIntBox(10)
        let binding = Binding<Int?>(get: { selected.value }, set: { selected.value = $0 })
        let submitted = Counter(), reached = Counter()

        _ = sessionLines(list(selection: binding, submitted: submitted, reached: reached), tree: tree)
        #expect(coord.handle(.enter))
        #expect(submitted.value == 1)
        #expect(reached.value == 0)

        _ = coord.handle(.end)
        _ = sessionLines(list(selection: binding, submitted: submitted, reached: reached), tree: tree)
        try await waitUntil { reached.value == 1 }
        _ = sessionLines(list(selection: binding, submitted: submitted, reached: reached), tree: tree)
        try await Task.sleep(nanoseconds: 30_000_000)
        #expect(reached.value == 1)
    }

    @Test("The sidebar style fills the selected row across the width")
    func sidebarStyle() {
        let coord = FocusCoordinator.shared
        coord.reset(); defer { coord.reset() }
        let selected = OptionalIntBox(0)
        let view = List(["a", "b"], selection: Binding(get: { selected.value }, set: { selected.value = $0 })) { Text($0) }
            .listStyle(.sidebar)
        let raw = view.renderString()
        #expect(raw.contains("\u{001B}[46m"))   // cyan background on the selected row
    }
}
}

// MARK: - Navigation and tabs

extension ControlSingletonTests {
@Suite("Typed navigation paths and tabs", .serialized)
struct NavigationPathTests {
    @Test("NavigationStack(path:) pushes through the binding and dismiss pops it")
    func typedPath() {
        let coord = FocusCoordinator.shared
        let store = BodyRenderingStore.shared
        coord.reset(); NavigationCoordinator.shared.reset(); store.fullScreenActive = true
        defer { coord.reset(); NavigationCoordinator.shared.reset(); store.fullScreenActive = false }
        let tree = RetainedTree()
        let path = PathBox()
        let box = PathDismissBox()
        let binding = Binding<[Route]>(get: { path.routes }, set: { path.routes = $0 })
        let view = NavigationStack(path: binding, id: "typed") {
            Text("root-content")
                .navigationDestination(for: Route.self) { route in
                    if case .detail(let id) = route { DetailPage(id: id, box: box) }
                }
            NavigationLink("Open 7", value: Route.detail(7))
        }

        var lines = sessionLines(view, tree: tree)
        #expect(lines.contains { $0.contains("root-content") })
        // Activating the value link appends to the app's path…
        _ = coord.handle(.enter)
        #expect(path.routes == [.detail(7)])
        lines = sessionLines(view, tree: tree)
        #expect(lines.contains { $0.contains("detail-7") })
        #expect(!lines.contains { $0.contains("root-content") })
        // …and dismiss() inside the destination removes it again.
        box.action?()
        #expect(path.routes.isEmpty)
        lines = sessionLines(view, tree: tree)
        #expect(lines.contains { $0.contains("root-content") })
        // A programmatic append works the same way.
        path.routes.append(.detail(3))
        lines = sessionLines(view, tree: tree)
        #expect(lines.contains { $0.contains("detail-3") })
    }

    fileprivate final class PathBox: @unchecked Sendable {
        var routes: [Route] = []
    }

    @Test("TabView keeps each tab's state and focused control across switches")
    func tabViewRetainsState() {
        let coord = FocusCoordinator.shared
        coord.reset(); defer { coord.reset() }
        let tree = RetainedTree()
        let probe = BindingProbe<Int>()
        let screen = StringBox("a")
        let binding = Binding<String>(get: { screen.value }, set: { screen.value = $0 })
        let view = TabView(selection: binding) {
            Tab("A", value: "a") {
                StatefulCounter(label: "a", probe: probe)
                Button("a1") {}
                Button("a2") {}
            }
            .badge(3)
            Tab("B", value: "b") {
                Text("b-content")
                Button("b1") {}
            }
        }

        var lines = sessionLines(view, tree: tree)
        #expect(lines.first?.contains("A") == true && lines.first?.contains("(3)") == true)
        #expect(lines.contains { $0 == "a=0" })
        probe.binding?.wrappedValue = 5
        _ = coord.handle(.tab)                      // focus a1 → a2
        #expect(coord.focused?.hasPrefix("a2") == true)

        screen.value = "b"
        lines = sessionLines(view, tree: tree)
        #expect(lines.contains { $0.contains("b-content") })
        #expect(!lines.contains { $0.contains("a=") })
        #expect(coord.focused?.hasPrefix("b1") == true)

        screen.value = "a"
        lines = sessionLines(view, tree: tree)
        #expect(lines.contains { $0 == "a=5" })     // state survived the switch
        #expect(coord.focused?.hasPrefix("a2") == true) // and so did the focus
    }
}
}

// MARK: - Overlays, insets, alerts, scrolling

extension ControlSingletonTests {
@Suite("Overlays, insets, alerts and scroll targets", .serialized)
struct OverlayTests {
    @Test("ZStack and overlay paint a layer over the base without resizing it")
    func zstackAndOverlay() {
        let stack = ZStack(alignment: .bottomTrailing) {
            Text("abcdef\nabcdef")
            Text("X")
        }
        #expect(stack.renderString().components(separatedBy: "\n").map { TextMetrics.stripANSI($0) } == ["abcdef", "abcdeX"])
        let overlaid = Text("abcdef\nabcdef").overlay(alignment: .topLeading) { Text("Y") }
        #expect(overlaid.renderString().components(separatedBy: "\n").map { TextMetrics.stripANSI($0) } == ["Ybcdef", "abcdef"])
        #expect(overlaid.measure() == Size(width: 6, height: 2))
    }

    @Test("safeAreaInset(edge: .bottom) pins its content to the last available row")
    func bottomInset() {
        let tree = RetainedTree()
        let view = VStack { Text("content") }.safeAreaInset(edge: .bottom) { Text("hint") }
        let lines = sessionLines(view, tree: tree, width: 20, height: 5)
        #expect(lines.count == 5)
        #expect(lines.first == "content")
        #expect(lines.last == "hint")
    }

    @Test("An alert shows its card over the content and any action dismisses it")
    func alertDismisses() {
        let coord = FocusCoordinator.shared
        let store = BodyRenderingStore.shared
        coord.reset(); SheetPresentationTracker.shared.reset(); store.fullScreenActive = true
        defer { coord.reset(); SheetPresentationTracker.shared.reset(); store.fullScreenActive = false }
        let tree = RetainedTree()
        let presented = BoolBox(true)
        let tapped = Counter()
        let hiddenFired = Counter()
        let view = VStack {
            Button("Base") { hiddenFired.increment() }
            Text("base-content")
        }
        .alert("Delete?", isPresented: Binding(get: { presented.value }, set: { presented.value = $0 })) {
            Button("Delete", role: .destructive) { tapped.increment() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("No undo.")
        }

        var lines = sessionLines(view, tree: tree)
        #expect(lines.contains { $0.contains("Delete?") })
        #expect(lines.contains { $0.contains("No undo.") })
        #expect(coord.focused?.hasPrefix("Delete") == true)    // focus moved into the card
        _ = coord.handle(.enter)
        #expect(tapped.value == 1)
        #expect(hiddenFired.value == 0)
        #expect(presented.value == false)                      // the action dismissed the alert
        lines = sessionLines(view, tree: tree)
        #expect(!lines.contains { $0.contains("Delete?") })
        #expect(coord.focused?.hasPrefix("Base") == true)
    }

    @Test("ScrollViewReader.scrollTo brings an id'd row to the top; focus moving into a row scrolls to it")
    func scrollToAndFocusFollow() {
        let coord = FocusCoordinator.shared
        coord.reset(); ScrollTargetRegistry.shared.reset()
        defer { coord.reset(); ScrollTargetRegistry.shared.reset() }
        let tree = RetainedTree()
        let proxyBox = ProxyBox()
        let view = ScrollViewReader { proxy in
            let _ = { proxyBox.proxy = proxy }()
            ScrollView {
                ForEach(0..<30) { i in Text("Row \(i)").id(i) }
            }
            .frame(height: 5)
        }
        var lines = sessionLines(view, tree: tree)
        #expect(lines.first?.hasPrefix("Row 0") == true)
        proxyBox.proxy?.scrollTo(12, anchor: .top)
        lines = sessionLines(view, tree: tree)
        #expect(lines.first?.hasPrefix("Row 12") == true)

        coord.reset()
        let buttons = ScrollView {
            ForEach(0..<20) { i in Button("b\(i)") {} }
        }
        .frame(height: 4)
        let other = RetainedTree()
        lines = sessionLines(buttons, tree: other)
        #expect(lines.contains { $0.contains("b0") })
        for _ in 0..<9 { _ = coord.handle(.tab) }
        #expect(coord.focused?.hasPrefix("b9") == true)
        lines = sessionLines(buttons, tree: other)
        #expect(lines.contains { $0.contains("b9") })
        #expect(!lines.contains { $0.contains("b0 ") || $0.hasSuffix("b0") })
    }

    @Test("ProgressView without a phase animates by itself inside a session")
    func progressViewSpins() {
        let store = BodyRenderingStore.shared
        store.sessionActive = false
        #expect(ProgressView("x").phase == 0)
        store.sessionActive = true
        defer { store.sessionActive = false; TimelineCoordinator.shared.reset() }
        #expect(ProgressView("x").phase != 0)
        #expect(ProgressView("x", phase: 3).phase == 3)
        _ = ProgressView("x").renderString()
        #expect(TimelineCoordinator.shared.hasArmedTimers)
    }

    @Test("Ctrl-C reaches onKeyPress first, and Page Up / Page Down decode")
    func interruptAndPaging() {
        let coord = FocusCoordinator.shared
        coord.reset(); defer { coord.reset() }
        let handled = Counter()
        let view = Text("x").onKeyPress { press in
            guard press.modifiers.contains(.control), press.key == "c" else { return .ignored }
            handled.increment()
            return .handled
        }
        _ = view.renderString()
        #expect(KeyPressRegistry.shared.dispatch(.interrupt, focusedControl: nil))
        #expect(handled.value == 1)

        var decoder = KeyDecoder()
        #expect(decoder.feed([0x1B, 0x5B, 0x35, 0x7E]) == [.pageUp])
        #expect(decoder.feed([0x1B, 0x5B, 0x36, 0x7E]) == [.pageDown])
    }
}
}

#endif
