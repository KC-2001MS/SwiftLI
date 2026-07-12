//
//  GridTests.swift
//  SwiftLITests
//
//  Created by Keisuke Chinone on 2026/07/12.
//

#if swift(>=6.0)
import Testing
@_spi(RenderingInternals) @testable import SwiftLI
import Foundation

// MARK: - Helpers

private func plain(_ s: String) -> String {
    TextMetrics.stripANSI(s)
}

private func plainLines(of view: some View) -> [String] {
    plain(view.renderString()).components(separatedBy: "\n")
}

// MARK: - VGrid Tests

@Suite("VGrid Testing")
struct VGridTests {

    // MARK: Initialization

    @Test("columns is clamped to 1 when initialized with 0")
    func columnsClampedFromZero() {
        let g = VGrid(columns: 0) { Text("X") }
        #expect(g.columns == 1)
    }

    @Test("columns is clamped to 1 when initialized with a negative value")
    func columnsClampedFromNegative() {
        let g = VGrid(columns: -5) { Text("X") }
        #expect(g.columns == 1)
    }

    @Test("columns is stored as-is for positive values")
    func columnsStoredCorrectly() {
        let g = VGrid(columns: 4) { Text("X") }
        #expect(g.columns == 4)
    }

    @Test("default spacing is 1")
    func defaultSpacing() {
        let g = VGrid(columns: 2) { Text("A"); Text("B") }
        #expect(g.spacing == 1)
    }

    @Test("spacing can be overridden at init")
    func customSpacing() {
        let g = VGrid(columns: 2, spacing: 3) { Text("A"); Text("B") }
        #expect(g.spacing == 3)
    }

    @Test("spacing 0 is stored correctly")
    func zeroSpacing() {
        let g = VGrid(columns: 2, spacing: 0) { Text("A"); Text("B") }
        #expect(g.spacing == 0)
    }

    // MARK: Size measurement — spacing: 0

    @Test("4 equal-width items in 2 columns with spacing 0 → 2×2")
    func size2x2NoSpacing() {
        // colWidth=[1,1]; 2 rows → width=2, height=2
        let g = VGrid(columns: 2, spacing: 0) {
            Text("A"); Text("B"); Text("C"); Text("D")
        }
        let size = g.measure()
        #expect(size.width == 2)
        #expect(size.height == 2)
    }

    @Test("6 equal-width items in 3 columns with spacing 0 → 3×2")
    func size3x2NoSpacing() {
        // colWidth=[1,1,1]; 2 rows → width=3, height=2
        let g = VGrid(columns: 3, spacing: 0) {
            Text("A"); Text("B"); Text("C")
            Text("D"); Text("E"); Text("F")
        }
        let size = g.measure()
        #expect(size.width == 3)
        #expect(size.height == 2)
    }

    @Test("3 equal-width items in 3 columns forms a single row")
    func singleRowNoSpacing() {
        let g = VGrid(columns: 3, spacing: 0) {
            Text("A"); Text("B"); Text("C")
        }
        let size = g.measure()
        #expect(size.width == 3)
        #expect(size.height == 1)
    }

    @Test("columns=1 behaves like a VStack")
    func singleColumnEqualsVStack() {
        // All items in one column → effectively a VStack
        let g = VGrid(columns: 1, spacing: 0) {
            Text("Hello"); Text("World")
        }
        let size = g.measure()
        // width = max(5, 5) = 5; height = 2
        #expect(size.width == 5)
        #expect(size.height == 2)
    }

    // MARK: Size measurement — with spacing

    @Test("4 equal-width items in 2 columns with spacing 1 → 3×3")
    func sizeWithDefaultSpacing() {
        // colWidth=[1,1]; row width=1+1(spacing)+1=3; 2 rows+1(spacing)=3
        let g = VGrid(columns: 2, spacing: 1) {
            Text("A"); Text("B"); Text("C"); Text("D")
        }
        let size = g.measure()
        #expect(size.width == 3)
        #expect(size.height == 3)
    }

    @Test("spacing 2 is reflected in both row and column gaps")
    func sizeWithSpacing2() {
        // colWidth=[1,1]; row width=1+2+1=4; 2 rows+2(spacing)=4
        let g = VGrid(columns: 2, spacing: 2) {
            Text("A"); Text("B"); Text("C"); Text("D")
        }
        let size = g.measure()
        #expect(size.width == 4)
        #expect(size.height == 4)
    }

    // MARK: Column width alignment

    @Test("column widths are aligned: widest cell in each column sets the width")
    func columnWidthAlignment() {
        // col0: max("A"=1, "DDDD"=4)=4; col1: "BB"=2; col2: "CCC"=3
        // Row 0: 4+2+3=9 wide; Row 1: 4 wide
        // VStack width = max(9, 4) = 9; height = 2
        let g = VGrid(columns: 3, spacing: 0) {
            Text("A"); Text("BB"); Text("CCC"); Text("DDDD")
        }
        let size = g.measure()
        #expect(size.width == 9)
        #expect(size.height == 2)
    }

    @Test("a wide item in row 2 widens all rows' column 0")
    func wideItemAlignsColumn() {
        // col0: max("Hi"=2, "LongWord"=8)=8; col1: "X"=1
        // Row 0: 8+1=9; Row 1: 8 (only col0 occupied)
        let g = VGrid(columns: 2, spacing: 0) {
            Text("Hi"); Text("X"); Text("LongWord")
        }
        let size = g.measure()
        #expect(size.width == 9)
        #expect(size.height == 2)
    }

    @Test("all columns in the same row are padded to their respective column width")
    func columnPaddingInRendering() {
        // col0: max("A"=1, "ZZZ"=3)=3; col1: "BB"=2
        // Row 0: "A" padded to 3 + "BB" padded to 2 → "A  BB"
        let g = VGrid(columns: 2, spacing: 0) {
            Text("A"); Text("BB"); Text("ZZZ"); Text("DD")
        }
        let rows = plainLines(of: g).filter { !$0.isEmpty }
        // First row: col0=3 cols ("A  ") + col1=2 cols ("BB") = "A  BB"
        #expect(rows.first?.hasPrefix("A") == true)
        // All rows should have the same width (3+2=5)
        #expect(rows.allSatisfy { $0.count == 5 })
    }

    // MARK: Rendering order

    @Test("items appear left-to-right within each row")
    func leftToRightOrder() {
        let g = VGrid(columns: 3, spacing: 1) {
            Text("A"); Text("B"); Text("C")
        }
        let rendered = plain(g.renderString())
        let ai = rendered.range(of: "A")!.lowerBound
        let bi = rendered.range(of: "B")!.lowerBound
        let ci = rendered.range(of: "C")!.lowerBound
        #expect(ai < bi && bi < ci)
    }

    @Test("earlier items appear above later items (top-to-bottom across rows)")
    func topToBottomOrder() {
        let g = VGrid(columns: 2, spacing: 0) {
            Text("A"); Text("B"); Text("C"); Text("D")
        }
        let rendered = plain(g.renderString())
        // A (row 0, col 0) must appear before C (row 1, col 0)
        let ai = rendered.range(of: "A")!.lowerBound
        let ci = rendered.range(of: "C")!.lowerBound
        #expect(ai < ci)
    }

    @Test("rendering contains all child text")
    func allItemsPresent() {
        let items = ["Alpha", "Beta", "Gamma", "Delta", "Epsilon"]
        let g = VGrid(columns: 3, spacing: 1) {
            ForEach(items) { Text($0) }
        }
        let rendered = plain(g.renderString())
        for item in items {
            #expect(rendered.contains(item), "Expected '\(item)' in rendered output")
        }
    }

    // MARK: Edge cases

    @Test("single item renders without crashing")
    func singleItem() {
        let g = VGrid(columns: 3, spacing: 0) { Text("Hello") }
        let size = g.measure()
        #expect(size.width == 5)
        #expect(size.height == 1)
    }

    @Test("empty VGrid does not crash")
    func emptyGrid() {
        let g = VGrid(columns: 3, spacing: 0) { EmptyView() }
        // Should not crash; size is zero
        let size = g.measure()
        #expect(size.width >= 0)
        #expect(size.height >= 0)
    }

    @Test("incomplete last row (5 items, 3 columns) renders correctly")
    func incompleteLastRow() {
        // rows: [A,B,C], [D,E] — last row has only 2 cells
        let g = VGrid(columns: 3, spacing: 0) {
            Text("A"); Text("B"); Text("C"); Text("D"); Text("E")
        }
        let rendered = plain(g.renderString())
        #expect(rendered.contains("A"))
        #expect(rendered.contains("E"))
        // Height = 2 rows
        let size = g.measure()
        #expect(size.height == 2)
    }

    @Test("row count equals ceil(itemCount / columns)")
    func rowCount() {
        let cases: [(items: Int, cols: Int, expectedRows: Int)] = [
            (6, 3, 2), (7, 3, 3), (3, 3, 1), (4, 3, 2), (1, 3, 1), (9, 3, 3)
        ]
        for c in cases {
            let g = VGrid(columns: c.cols, spacing: 0) {
                ForEach(0..<c.items) { _ in Text("X") }
            }
            let rows = plainLines(of: g).filter { !$0.isEmpty }
            #expect(rows.count == c.expectedRows,
                    "items=\(c.items), cols=\(c.cols): expected \(c.expectedRows) rows, got \(rows.count)")
        }
    }

    @Test("spacing 0 produces no gaps — cells are directly adjacent")
    func noGapsWithZeroSpacing() {
        // 2 items in 2 columns, single-char items → row = "AB" (width 2)
        let g = VGrid(columns: 2, spacing: 0) {
            Text("A"); Text("B")
        }
        let rows = plainLines(of: g).filter { !$0.isEmpty }
        #expect(rows.count == 1)
        #expect(rows.first == "AB")
    }
}

// MARK: - HGrid Tests

@Suite("HGrid Testing")
struct HGridTests {

    // MARK: Initialization

    @Test("rows is clamped to 1 when initialized with 0")
    func rowsClampedFromZero() {
        let g = HGrid(rows: 0) { Text("X") }
        #expect(g.rows == 1)
    }

    @Test("rows is clamped to 1 when initialized with a negative value")
    func rowsClampedFromNegative() {
        let g = HGrid(rows: -3) { Text("X") }
        #expect(g.rows == 1)
    }

    @Test("rows is stored as-is for positive values")
    func rowsStoredCorrectly() {
        let g = HGrid(rows: 4) { Text("X") }
        #expect(g.rows == 4)
    }

    @Test("default spacing is 1")
    func defaultSpacing() {
        let g = HGrid(rows: 2) { Text("A"); Text("B") }
        #expect(g.spacing == 1)
    }

    @Test("spacing can be overridden at init")
    func customSpacing() {
        let g = HGrid(rows: 2, spacing: 2) { Text("A"); Text("B") }
        #expect(g.spacing == 2)
    }

    @Test("spacing 0 is stored correctly")
    func zeroSpacing() {
        let g = HGrid(rows: 2, spacing: 0) { Text("A"); Text("B") }
        #expect(g.spacing == 0)
    }

    // MARK: Size measurement — spacing: 0

    @Test("4 equal-size items in 2 rows with spacing 0 → 2×2")
    func size2x2NoSpacing() {
        // rowHeight=[1,1]; 2 cols → width=2, height=2
        let g = HGrid(rows: 2, spacing: 0) {
            Text("A"); Text("B"); Text("C"); Text("D")
        }
        let size = g.measure()
        #expect(size.width == 2)
        #expect(size.height == 2)
    }

    @Test("6 equal-size items in 2 rows with spacing 0 → 3×2")
    func size3x2NoSpacing() {
        // rowHeight=[1,1]; 3 cols → width=3, height=2
        let g = HGrid(rows: 2, spacing: 0) {
            Text("A"); Text("B"); Text("C"); Text("D"); Text("E"); Text("F")
        }
        let size = g.measure()
        #expect(size.width == 3)
        #expect(size.height == 2)
    }

    @Test("2 items in 2 rows forms a single column")
    func singleColumnNoSpacing() {
        // col0=[A,B]; width=1, height=2
        let g = HGrid(rows: 2, spacing: 0) {
            Text("A"); Text("B")
        }
        let size = g.measure()
        #expect(size.width == 1)
        #expect(size.height == 2)
    }

    @Test("rows=1 behaves like an HStack")
    func singleRowEqualsHStack() {
        // All items in one row → effectively an HStack
        let g = HGrid(rows: 1, spacing: 0) {
            Text("Hello"); Text("World")
        }
        let size = g.measure()
        // HStack(spacing:0): width=5+5=10, height=1
        #expect(size.width == 10)
        #expect(size.height == 1)
    }

    // MARK: Size measurement — with spacing

    @Test("4 equal-size items in 2 rows with spacing 1 → 3×3")
    func sizeWithDefaultSpacing() {
        // rowHeight=[1,1]; col VStack(spacing:1): height=1+1+1=3
        // HStack(spacing:1): width=1+1+1=3
        let g = HGrid(rows: 2, spacing: 1) {
            Text("A"); Text("B"); Text("C"); Text("D")
        }
        let size = g.measure()
        #expect(size.width == 3)
        #expect(size.height == 3)
    }

    @Test("spacing 2 is reflected in both column and row gaps")
    func sizeWithSpacing2() {
        // rowHeight=[1,1]; col VStack(spacing:2): height=1+2+1=4
        // HStack(spacing:2): width=1+2+1=4
        let g = HGrid(rows: 2, spacing: 2) {
            Text("A"); Text("B"); Text("C"); Text("D")
        }
        let size = g.measure()
        #expect(size.width == 4)
        #expect(size.height == 4)
    }

    // MARK: Row height alignment

    @Test("row heights are aligned across all columns")
    func rowHeightAlignment() {
        // Child 0 (col0, row0): 2-line VStack → height=2
        // Child 1 (col0, row1): Text("C") → height=1
        // Child 2 (col1, row0): Text("X") → height=1
        // Child 3 (col1, row1): Text("Y") → height=1
        // rowHeight[0] = max(2,1) = 2; rowHeight[1] = max(1,1) = 1
        // Each col VStack(spacing:0): height=2+1=3; width=1
        // HStack(spacing:0): width=2, height=3
        let g = HGrid(rows: 2, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) { Text("A"); Text("B") }
            Text("C")
            Text("X")
            Text("Y")
        }
        let size = g.measure()
        #expect(size.height == 3)
        #expect(size.width == 2)
    }

    @Test("the taller row height forces all columns to the same row height")
    func tallRowHeightPropagates() {
        // Child 0 (col0, row0): 3-line VStack → height=3
        // Child 1 (col0, row1): 1-line Text → height=1
        // Child 2 (col1, row0): 1-line Text → height=1 → rowHeight[0]=3
        // Child 3 (col1, row1): 1-line Text → height=1
        // Each col VStack(spacing:0): height=3+1=4
        // Overall: width=2, height=4
        let g = HGrid(rows: 2, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) { Text("A"); Text("B"); Text("C") }
            Text("D")
            Text("E")
            Text("F")
        }
        let size = g.measure()
        #expect(size.height == 4)
    }

    // MARK: Rendering order

    @Test("items fill top-to-bottom within each column (first column)")
    func topToBottomFillInColumn() {
        // rows=2: col0=[A,B], col1=[C,D]
        // Output line 0: "A C"  (row 0 of each col)
        // Output line 1: "B D"  (row 1 of each col)
        // A (row 0) must appear before B (row 1) in the output string
        let g = HGrid(rows: 2, spacing: 1) {
            Text("A"); Text("B"); Text("C"); Text("D")
        }
        let rendered = plain(g.renderString())
        let ai = rendered.range(of: "A")!.lowerBound
        let bi = rendered.range(of: "B")!.lowerBound
        #expect(ai < bi)
    }

    @Test("items in column 0 row 0 and column 1 row 0 appear on the same line")
    func sameRowAppearsOnSameLine() {
        // A (col0,row0) and C (col1,row0) should be on the first line
        let g = HGrid(rows: 2, spacing: 1) {
            Text("A"); Text("B"); Text("C"); Text("D")
        }
        let rendered = plain(g.renderString())
        let firstNewline = rendered.firstIndex(of: "\n") ?? rendered.endIndex
        let ai = rendered.range(of: "A")!.lowerBound
        let ci = rendered.range(of: "C")!.lowerBound
        #expect(ai < firstNewline)
        #expect(ci < firstNewline)
    }

    @Test("columns fill left-to-right (col 0 items appear before col 1 items on each line)")
    func leftToRightColumnOrder() {
        // col0=[A,B], col1=[C,D]: A appears left of C on row 0
        let g = HGrid(rows: 2, spacing: 1) {
            Text("A"); Text("B"); Text("C"); Text("D")
        }
        let rendered = plain(g.renderString())
        let ai = rendered.range(of: "A")!.lowerBound
        let ci = rendered.range(of: "C")!.lowerBound
        #expect(ai < ci)
    }

    @Test("rendering contains all child text")
    func allItemsPresent() {
        let items = ["Alpha", "Beta", "Gamma", "Delta"]
        let g = HGrid(rows: 2, spacing: 1) {
            ForEach(items) { Text($0) }
        }
        let rendered = plain(g.renderString())
        for item in items {
            #expect(rendered.contains(item), "Expected '\(item)' in rendered output")
        }
    }

    // MARK: Edge cases

    @Test("single item renders without crashing")
    func singleItem() {
        let g = HGrid(rows: 3, spacing: 0) { Text("Hello") }
        let size = g.measure()
        #expect(size.width == 5)
        #expect(size.height == 1)
    }

    @Test("empty HGrid does not crash")
    func emptyGrid() {
        let g = HGrid(rows: 2, spacing: 0) { EmptyView() }
        let size = g.measure()
        #expect(size.width >= 0)
        #expect(size.height >= 0)
    }

    @Test("incomplete last column (3 items, 2 rows) renders all items")
    func incompleteLastColumn() {
        // col0=[A,B], col1=[C] — last column has only 1 item
        let g = HGrid(rows: 2, spacing: 0) {
            Text("A"); Text("B"); Text("C")
        }
        let rendered = plain(g.renderString())
        #expect(rendered.contains("A"))
        #expect(rendered.contains("B"))
        #expect(rendered.contains("C"))
    }

    @Test("spacing 0 produces a compact single-column layout for 2 items in 2 rows")
    func compactTwoItemLayout() {
        // 2 items in 2 rows → single column, spacing=0
        let g = HGrid(rows: 2, spacing: 0) {
            Text("A"); Text("B")
        }
        let rows = plainLines(of: g).filter { !$0.isEmpty }
        #expect(rows.count == 2)
        #expect(rows[0] == "A")
        #expect(rows[1] == "B")
    }

    @Test("column count equals ceil(itemCount / rows)")
    func columnCount() {
        let cases: [(items: Int, rows: Int, expectedCols: Int)] = [
            (4, 2, 2), (6, 2, 3), (2, 2, 1), (3, 2, 2), (1, 2, 1), (6, 3, 2)
        ]
        for c in cases {
            let g = HGrid(rows: c.rows, spacing: 0) {
                ForEach(0..<c.items) { _ in Text("X") }
            }
            let outputRows = plainLines(of: g).filter { !$0.isEmpty }
            // In the first output row, the number of "X" characters equals the column count
            let xCount = outputRows.first?.filter { $0 == "X" }.count ?? 0
            #expect(xCount == c.expectedCols,
                    "items=\(c.items), rows=\(c.rows): expected \(c.expectedCols) cols, got \(xCount)")
        }
    }
}

#endif
