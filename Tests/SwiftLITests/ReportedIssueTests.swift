//
//  ReportedIssueTests.swift
//  SwiftLITests
//
//  Created by Keisuke Chinone on 2026/11/08.
//

#if swift(>=6.0)
import Testing
import Observation
@_spi(RenderingInternals) @testable import SwiftLI
import Foundation

// Regression tests for behaviour reported from an app built on SwiftLI:
// `@Environment` read from closures, the rows a TabView / NavigationStack
// reserves for its bars, text wrapping inside an HStack, and Escape with a
// non-text control focused.

/// One frame of a session: the pass is bracketed so controls register, the
/// view keeps `tree` between frames, and the root is proposed `width`
/// columns in a `height`-row terminal.
private func frameLines(_ view: any View, tree: RetainedTree, width: Int = 40, height: Int = 24) -> [String] {
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
private func oneShotLines(_ view: any View, width: Int) -> [String] {
    NodeLayout.frame(of: view.makeNode(), proposedWidth: width).lines.map { TextMetrics.stripANSI($0) }
}

// MARK: - @Environment outside rendering

@Observable
private final class ProbeModel: @unchecked Sendable {
    var count = 0
}

private final class ClosureBox: @unchecked Sendable {
    var object: (() -> AnyObject)?
    var width: (() -> Int)?
}

/// Reads two environment values in `body` and hands closures that read
/// them again to the test — the way a `Button` action or `.task` would.
private struct EnvironmentProbe: View {
    @Environment(ProbeModel.self) private var model
    @Environment(\.maxWidth) private var maxWidth
    let box: ClosureBox

    var body: some View {
        let _ = {
            box.object = { model }
            box.width = { maxWidth }
        }()
        Text("count \(model.count) in \(maxWidth)")
    }
}

// Every suite below is nested inside ControlSingletonTests so it never runs
// in parallel with the other tests that share the focus / navigation /
// lifecycle singletons.
extension ControlSingletonTests {
@Suite("@Environment read from closures", .serialized)
struct EnvironmentClosureTests {
    @Test("A closure that runs outside any render pass sees the values body resolved")
    func rememberedOutsideRendering() {
        let model = ProbeModel()
        let box = ClosureBox()
        let view = EnvironmentProbe(box: box).environment(model).frame(width: 17)
        let lines = frameLines(view, tree: RetainedTree(), width: 40, height: 10)
        #expect(lines.first?.contains("count 0 in 17") == true)

        // No pass is active here, so a lazy read would see the root
        // environment — no object (a fatalError) and the terminal width.
        #expect(RenderPassContext.current == nil)
        #expect(box.object?() === model)
        #expect(box.width?() == 17)
    }

    @Test("A re-render under a new scope updates what the closures see")
    func followsTheLatestRender() {
        let first = ProbeModel()
        let second = ProbeModel()
        let box = ClosureBox()
        let tree = RetainedTree()
        _ = frameLines(EnvironmentProbe(box: box).environment(first), tree: tree)
        #expect(box.object?() === first)
        _ = frameLines(EnvironmentProbe(box: box).environment(second), tree: tree)
        #expect(box.object?() === second)
    }
}
}

// MARK: - Rows reserved for bars

private final class HeightBox: @unchecked Sendable {
    var value = 0
}

/// Records the `\.maxHeight` its content is laid out against.
private struct HeightProbe: View {
    @Environment(\.maxHeight) private var maxHeight
    let box: HeightBox

    var body: some View {
        let _ = { box.value = maxHeight }()
        Text("probe")
    }
}

private final class PathHolder: @unchecked Sendable {
    var values: [Int] = []
}

private final class DismissHolder: @unchecked Sendable {
    var action: DismissAction?
}

/// A pushed page that hands its `\.dismiss` to the test.
private struct DismissProbe: View {
    @Environment(\.dismiss) private var dismiss
    let value: Int
    let holder: DismissHolder

    var body: some View {
        let _ = { holder.action = dismiss }()
        Text("detail-\(value)")
    }
}

extension ControlSingletonTests {
@Suite("Bars reserve rows out of maxHeight", .serialized)
struct ChromeHeightTests {
    @Test("A TabView's bar and rule take two rows from its tabs")
    func tabViewReservesBarRows() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }
        let box = HeightBox()
        let view = TabView {
            Tab("A", value: 0) { HeightProbe(box: box) }
            Tab("B", value: 1) { Text("b") }
        }
        let lines = frameLines(view, tree: RetainedTree(), width: 30, height: 12)
        #expect(box.value == 10)
        #expect(lines.count == 3)   // bar, rule, probe
    }

    @Test("A NavigationStack's title bar takes its rows from the layers, from the second frame on")
    func navigationStackReservesTitleRows() {
        let coord = FocusCoordinator.shared
        coord.reset(); NavigationCoordinator.shared.reset()
        defer { coord.reset(); NavigationCoordinator.shared.reset() }
        let box = HeightBox()
        let tree = RetainedTree()
        let view = NavigationStack(id: "chrome") {
            HeightProbe(box: box)
                .navigationTitle("Title")
                .navigationSubtitle("Subtitle")
        }
        // The first frame cannot know the bar yet (the title registers while
        // the content lowers); it records the rows and asks for another.
        _ = frameLines(view, tree: tree, width: 30, height: 12)
        let lines = frameLines(view, tree: tree, width: 30, height: 12)
        #expect(lines.prefix(3).map { $0.trimmingCharacters(in: .whitespaces) } == ["Title", "Subtitle", String(repeating: "─", count: 30)])
        #expect(box.value == 9)
    }

    @Test("A list inside a tab view no longer pushes a bottom inset off the screen")
    func listKeepsFooterVisible() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }
        let selected = SelectionBox()
        let selection = Binding<Int?>(get: { selected.value }, set: { selected.value = $0 })
        let view = TabView {
            Tab("Items", value: 0) {
                List(Array(1...40), selection: selection) { Text("row \($0)") }
            }
        }
        .safeAreaInset(edge: .bottom) { Text("footer") }
        let tree = RetainedTree()
        let lines = frameLines(view, tree: tree, width: 30, height: 12)
        #expect(lines.count == 12)
        #expect(lines.last == "footer")
    }

    @Test("Two stacks without an explicit id, one per tab, keep separate bar rows and path bindings")
    func stacksInTabsStaySeparate() {
        let coord = FocusCoordinator.shared
        let store = BodyRenderingStore.shared
        coord.reset(); NavigationCoordinator.shared.reset(); store.fullScreenActive = true
        defer { coord.reset(); NavigationCoordinator.shared.reset(); store.fullScreenActive = false }
        let tree = RetainedTree()
        let path = PathHolder()
        let binding = Binding<[Int]>(get: { path.values }, set: { path.values = $0 })
        let box = HeightBox()
        let dismissed = DismissHolder()
        let view = TabView {
            Tab("Items", value: 0) {
                NavigationStack(path: binding) {
                    HeightProbe(box: box)
                        .navigationTitle("Items")
                        .navigationSubtitle("subtitle")
                        .navigationDestination(for: Int.self) { value in DismissProbe(value: value, holder: dismissed) }
                }
            }
            Tab("Settings", value: 1) {
                NavigationStack { Text("settings").navigationTitle("Settings") }
            }
        }
        _ = frameLines(view, tree: tree, width: 30, height: 12)
        var lines = frameLines(view, tree: tree, width: 30, height: 12)
        #expect(lines.first?.contains("Items") == true)
        // Bar (2) + title, subtitle, rule (3) — not the inert Settings
        // stack's two rows, which used to be recorded under the same id.
        #expect(box.value == 7)
        lines = frameLines(view, tree: tree, width: 30, height: 12)
        #expect(box.value == 7)   // and it stays put, frame after frame

        // dismiss() inside the pushed value pops through the binding, even
        // though the Settings stack registers no binding every pass.
        path.values = [7]
        lines = frameLines(view, tree: tree, width: 30, height: 12)
        #expect(lines.contains { $0.contains("detail-7") })
        dismissed.action?()
        #expect(path.values.isEmpty)
        lines = frameLines(view, tree: tree, width: 30, height: 12)
        #expect(lines.contains { $0.contains("probe") })
    }

    fileprivate final class SelectionBox: @unchecked Sendable {
        var value: Int? = 0   // the selected row's index
    }
}
}

// MARK: - HStack width division

extension ControlSingletonTests {
@Suite("Text wraps inside an HStack", .serialized)
struct RowWrappingTests {
    @Test("A row that overflows its proposal wraps the longest text and keeps the label's column")
    func textWrapsInRow() {
        let view = HStack(alignment: .top, spacing: 1) {
            Text("Name:")
            Text("a long value that needs wrapping")
        }
        let lines = oneShotLines(view, width: 20)
        #expect(lines == ["Name: a long value", "      that needs", "      wrapping"])
    }

    @Test("A row that fits keeps every child's natural width")
    func fittingRowIsUnchanged() {
        let view = HStack(spacing: 1) { Text("Name:"); Text("short") }
        #expect(oneShotLines(view, width: 20) == ["Name: short"])
    }

    @Test("A fixed-width frame keeps its width; the text beside it takes the rest")
    func fixedFrameKeepsWidth() {
        let view = HStack(alignment: .top, spacing: 0) {
            Text("x").frame(width: 10, alignment: .leading)
            Text("one two three four")
        }
        let lines = oneShotLines(view, width: 20)
        #expect(lines.count == 2)
        #expect(lines[0] == "x         one two")
        #expect(lines[1].hasSuffix("three four"))
        #expect(lines.allSatisfy { TextMetrics.visibleWidth($0) <= 20 })
    }

    @Test("Rows inside a session wrap the same way, frame after frame")
    func wrapsInsideSession() {
        let tree = RetainedTree()
        let view = VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 1) { Text("Name:"); Text("a long value that needs wrapping") }
            Text("below")
        }
        for _ in 0..<2 {
            let lines = frameLines(view, tree: tree, width: 20, height: 10)
            #expect(lines == ["Name: a long value", "      that needs", "      wrapping", "below"])
        }
    }
}
}

// MARK: - Escape with a focused control

extension ControlSingletonTests {
@Suite("Escape and focus", .serialized)
struct EscapeFocusTests {
    @Test("Escape is left to the onKeyPress handlers while a button is focused")
    func escapePassesNonTextControl() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }
        let tree = RetainedTree()
        _ = frameLines(Button("Go") {}, tree: tree)
        #expect(coord.focused != nil)
        #expect(coord.handle(.escape) == false)
        #expect(coord.focused != nil)
    }

    @Test("Escape still leaves a focused text field")
    func escapeBlursTextField() {
        let coord = FocusCoordinator.shared
        coord.reset()
        defer { coord.reset() }
        let text = StringBox("")
        let tree = RetainedTree()
        _ = frameLines(TextField("Name", text: Binding(get: { text.value }, set: { text.value = $0 })), tree: tree)
        #expect(coord.focused != nil)
        #expect(coord.handle(.escape) == true)
        #expect(coord.focused == nil)
    }
}
}
#endif
