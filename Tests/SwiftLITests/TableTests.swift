//
//  TableTests.swift
//  SwiftLITests
//
//  Created by Keisuke Chinone on 2026/07/10.
//

#if swift(>=6.0)
import Testing
@_spi(RenderingInternals) @testable import SwiftLI
import Foundation

@Suite("Table Testing")
struct TableTests {
    struct Person { let name: String; let email: String }

    private func plainLines(_ node: RenderNode) -> [String] {
        NodeLayout.frame(of: node).lines.map { TextMetrics.stripANSI($0) }
    }

    @Test("A table renders a header, a rule, and one row per element")
    func structure() {
        let people = [Person(name: "Ada", email: "ada@x.io"),
                      Person(name: "Bob", email: "bob@x.io")]
        let node = Table(people) {
            TableColumn("Name") { $0.name }
            TableColumn("Email") { $0.email }
        }.makeNode()
        let lines = plainLines(node).filter { !$0.isEmpty }
        #expect(lines.count == 4)                       // header + rule + 2 rows
        #expect(lines[0].contains("Name"))
        #expect(lines[0].contains("Email"))
        #expect(lines[1].allSatisfy { $0 == "─" })      // the rule
        #expect(lines[2].contains("Ada"))
        #expect(lines[3].contains("Bob"))
    }

    @Test("A value wider than its fixed column is truncated with an ellipsis")
    func truncatesCell() {
        let rows = [Person(name: "x", email: "an-extremely-long-email-address@example.com")]
        let node = Table(rows) {
            TableColumn("Name", width: 4) { $0.name }
            TableColumn("Email", width: 10) { $0.email }
        }.makeNode()
        let lines = plainLines(node).filter { !$0.isEmpty }
        #expect(lines.last?.contains("…") == true)
    }

    @Test("A tall table pins the header and shows only a height-row body window")
    func scrollsBodyUnderPinnedHeader() {
        let people = (0..<20).map { Person(name: "Name\($0)", email: "e\($0)") }
        // No selection → plain scroll; body height 4, fresh id → offset 0.
        let node = Table(people, height: 4, id: "tbl-scroll-test") {
            TableColumn("Name") { $0.name }
            TableColumn("Email") { $0.email }
        }.makeNode()
        let lines = plainLines(node).filter { !$0.isEmpty }
        // header + rule + 4 body rows = 6 lines (not all 20 rows).
        #expect(lines.count == 6)
        #expect(lines[0].contains("Name"))
        #expect(lines[1].allSatisfy { $0 == "─" })
        #expect(lines[2].contains("Name0"))
        #expect(lines[5].contains("Name3"))
    }
}

#endif
