//
//  ViewBuilderTests.swift
//  SwiftLITests
//
//  Created by Keisuke Chinone on 2026/07/10.
//

#if swift(>=6.0)
import Testing
@_spi(RenderingInternals) @testable import SwiftLI
import Foundation

@Suite("View Protocol Testing",.tags(.general))
struct ViewProtocolTests {
    @Suite(.tags(.normalBehavior))
    struct NormalBehavior {
        @Test("The number of elements added to the ViewBuilder matches the number of elements in the array.")
        func elementCountTesting() throws {
            @ViewBuilder
            var views: TupleView<Text, Text, Text> {
                Text("")
                Text("")
                Text("")
            }
            
            #expect(views._flattenedChildren().count == 3)
        }
    }
}


@Suite("Group Testing", .tags(.group))
struct GroupTests {
    @Suite(.tags(.normalBehavior))
    struct NormalBehavior {
        @Test("Is the value of the contents variable correct when initialized?")
        func contentsVariableInitialValueTesting() async throws {
            let group1 = Group {
                Text("")
            }
            let group2 = Group(contents: [Text("")])
            
            #expect(group1.contents.count == 1)
            #expect(group2.contents.count == 1)
        }
        
    }
}

@Suite("ForEach Testing")
struct ForEachTests {
    @Test("ForEach over an array produces one row per element in a VStack")
    func forEachArrayInVStack() {
        let fruits = ["Apple", "Banana", "Cherry"]
        let view = VStack {
            ForEach(fruits) { Text($0) }
        }
        let lines = view.renderString().components(separatedBy: "\n").map(sgrStripped)
        #expect(lines == fruits)
    }

    @Test("ForEach over a range produces one column per element in an HStack")
    func forEachRangeInHStack() {
        let view = HStack(spacing: 1) {
            ForEach(0..<5) { Text("\($0)") }
        }
        let plain = sgrStripped(view.renderString())
        #expect(plain == "0 1 2 3 4")
    }

    @Test("ForEach generates exactly `data.count` children")
    func forEachChildCount() {
        let view = ForEach(0..<7) { Text("\($0)") }
        guard case .group(let children) = view.makeNode() else {
            Issue.record("ForEach should lower to a group node")
            return
        }
        #expect(children.count == 7)
    }

    @Test("An empty ForEach produces no children")
    func forEachEmpty() {
        let view = ForEach([Int]()) { Text("\($0)") }
        guard case .group(let children) = view.makeNode() else {
            Issue.record("ForEach should lower to a group node")
            return
        }
        #expect(children.isEmpty)
    }

    @Test("A style modifier on ForEach cascades to every generated child")
    func forEachStyleCascade() {
        let green = "\u{001B}[3\(Color.green.ansi)m"
        let view = ForEach(0..<3) { Text("\($0)") }.forgroundColor(.green)
        let raw = view.renderString()
        // Every one of the three rows must carry the green foreground code.
        let occurrences = raw.components(separatedBy: green).count - 1
        #expect(occurrences == 3)
    }
}

@Suite("Conditional Rendering Testing")
struct ConditionalRenderingTests {
    @ViewBuilder
    private func content(_ show: Bool) -> some View {
        if show {
            Text("Visible")
        }
    }

    private func lines(_ v: some View) -> [String] {
        NodeLayout.frame(of: v.makeNode()).lines
            .map { TextMetrics.stripANSI($0) }
            .filter { !$0.isEmpty }
    }

    @Test("A false `if` branch renders nothing — hiding is handled by the IR, not a view")
    func falseBranchIsEmpty() {
        #expect(lines(content(false)).isEmpty)
    }

    @Test("A true `if` branch renders its content")
    func trueBranchShowsContent() {
        #expect(lines(content(true)).contains { $0.contains("Visible") })
    }
}

#endif
