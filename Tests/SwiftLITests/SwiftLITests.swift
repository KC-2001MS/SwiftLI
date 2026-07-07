#if swift(>=6.0)
import Testing
@_spi(RenderingInternals) @testable import SwiftLI
import Foundation

extension Tag {
    @Tag static var general: Self
    @Tag static var viewProtocol: Self
    @Tag static var text: Self
    @Tag static var group: Self
    @Tag static var hdivider: Self
    @Tag static var spacer: Self
    @Tag static var emotion: Self
    
    @Tag static var normalBehavior: Self
}

let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

let randomInt = Int.random(in: 5..<20)

let randomStrings = String((0..<randomInt).map{ _ in letters.randomElement()! })

let randomCharacter = randomStrings.randomElement()!

let allColors: [Color] = [
    .black,
    .red,
    .green,
    .yellow,
    .blue,
    .magenta,
    .cyan,
    .white,
    .eight_bit(202),
    .primary
]

@Suite("View Protocol Testing",.tags(.general))
struct ViewProtocolTests {
    @Suite(.tags(.normalBehavior))
    struct NormalBehavior {
        @Test("The number of elements added to the ViewBuilder matches the number of elements in the array.")
        func elementCountTesting() throws {
            @ViewBuilder
            var views: Group {
                Text("")
                Text("")
                Text("")
            }
            
            #expect(views.contents.count == 3)
        }
    }
}

@Suite("Text Testing",.tags(.text))
struct TextTests {
    @Suite(.tags(.normalBehavior))
    struct NormalBehavior {
        @Test("Is the value of the header variable correct when initialized?", arguments: [(randomStrings, randomInt, randomCharacter)])
        func headerVariableInitialValueTesting(
            string: String,
            int: Int,
            character: Character
        ) async throws {
            let text1 = Text(string)
            let text2 = Text(repeating: character, count: int)
            let text3 = Text(header: string, repeating: character, count: int)
            let text4 = Text(header: string, content: string)
            
            #expect(text1.header.isEmpty)
            #expect(text2.header.isEmpty)
            #expect(text3.header == randomStrings)
            #expect(text4.header == randomStrings)
        }
        
        @Test("Is the value of the content variable correct when initialized?", arguments:  [(randomStrings, randomInt, randomCharacter)])
        func contentVariableInitialValueTesting(
            string: String,
            int: Int,
            character: Character
        ) async throws {
            let text1 = Text(string)
            let text2 = Text(repeating: character, count: int)
            let text3 = Text(header: string, repeating: character, count: int)
            let text4 = Text(header: string, content: string)
            
            #expect(text1.contents == [string])
            #expect(text2.contents == [String(repeating: character, count: int)])
            #expect(text3.contents == [String(repeating: character, count: int)])
            #expect(text4.contents == [string])
        }
        
        @Test("Is the color set by the forgroundColor function applied to the header variable?", arguments: allColors)
        func forgroundColorFuncTesting(
            color: Color
        ) async throws {
            let text = Text("").forgroundColor(color).forgroundColor(color)
            
            #expect(text.header == "\u{001B}[3\(color.ansi)m\u{001B}[3\(color.ansi)m")
        }
        
        @Test("Is the color set by the background function applied to the header variable?", arguments: allColors)
        func backgroundFuncTesting(
            color: Color
        ) async throws {
            let text = Text("").background(color).background(color)
            
            #expect(text.header == "\u{001B}[4\(color.ansi)m\u{001B}[4\(color.ansi)m")
        }
        
        @Test("Is the thickness set by the bold function applied to the header variable?")
        func boldFuncTesting() async throws {
            let text1 = Text("").bold()
            let text2 = Text("").bold(true)
            let text3 = Text("").bold(false)
            
            #expect(text1.header == "\u{001B}[1m")
            #expect(text2.header == "\u{001B}[1m")
            #expect(text3.header.isEmpty)
        }
        
        @Test("Is the thickness set by the fontWeight function applied to the header variable?", arguments: Weight.allCases)
        func fontWeightFuncTesting(
            weight: Weight
        ) async throws {
            let text = Text("").fontWeight(weight)
            
            if weight == .default {
                #expect(text.header.isEmpty)
            } else {
                #expect(text.header == "\u{001B}[\(weight.rawValue)m")
            }
        }
        
        @Test("Is the style set by the italic function applied to the header variable?")
        func italicFuncTesting() async throws {
            let text1 = Text("").italic()
            let text2 = Text("").italic(true)
            let text3 = Text("").italic(false)
            
            #expect(text1.header == "\u{001B}[3m")
            #expect(text2.header == "\u{001B}[3m")
            #expect(text3.header.isEmpty)
        }
        
        @Test("Is the style set by the underline function applied to the header variable?")
        func underlineFuncTesting() async throws {
            let text1 = Text("").underline()
            let text2 = Text("").underline(true)
            let text3 = Text("").underline(false)
            
            #expect(text1.header == "\u{001B}[4m")
            #expect(text2.header == "\u{001B}[4m")
            #expect(text3.header.isEmpty)
        }
        
        @Test("Is the style set by the blink function applied to the header variable?", arguments: BlinkStyle.allCases)
        func blinkFuncTesting(
            blink: BlinkStyle
        ) async throws {
            let text = Text("").blink(blink)
            
            if blink == .none {
                #expect(text.header.isEmpty)
            } else {
                #expect(text.header == "\u{001B}[\(blink.rawValue)m")
            }
        }
        
        @Test("Is the style set by the hidden function applied to the header variable?")
        func hiddenFuncTesting() async throws {
            let text1 = Text("").hidden()
            let text2 = Text("").hidden(true)
            let text3 = Text("").hidden(false)
            
            #expect(text1.header == "\u{001B}[8m")
            #expect(text2.header == "\u{001B}[8m")
            #expect(text3.header.isEmpty)
        }
        
        @Test("Is the style set by the strikethrough function applied to the header variable?")
        func strikethroughFuncTesting() async throws {
            let text1 = Text("").strikethrough()
            let text2 = Text("").strikethrough(true)
            let text3 = Text("").strikethrough(false)
            
            #expect(text1.header == "\u{001B}[9m")
            #expect(text2.header == "\u{001B}[9m")
            #expect(text3.header.isEmpty)
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

@Suite("Divider Testing")
struct DividerTests {
    @Suite(.tags(.normalBehavior))
    struct NormalBehavior {
        @Test("Is the value of the header variable correct when initialized?", arguments: [(randomStrings, randomInt, randomCharacter)])
        func headerVariableInitialValueTesting(
            string: String,
            int: Int,
            character: Character
        ) async throws {
            let hDivider1 = Divider(int)
            let hDivider2 = Divider(header: string, character: character, verticalCharacter: "|", count: int)
            
            #expect(hDivider1.header.isEmpty)
            #expect(hDivider2.header == string)
        }
        
        @Test("Is the value of the character variable correct when initialized?", arguments: [(randomStrings, randomInt, randomCharacter)])
        func characterVariableInitialValueTesting(
            string: String,
            int: Int,
            character: Character
        ) async throws {
            let hDivider1 = Divider(int)
            let hDivider2 = Divider(header: string, character: character, verticalCharacter: "|", count: int)
            
            #expect(hDivider1.character == "-")
            #expect(hDivider2.character == randomCharacter)
        }
        
        @Test("Is the value of the count variable correct when initialized?", arguments: [(randomStrings, randomInt, randomCharacter)])
        func countVariableInitialValueTesting(
            string: String,
            int: Int,
            character: Character
        ) async throws {
            let hDivider1 = Divider(int)
            let hDivider2 = Divider(header: string, character: character, verticalCharacter: "|", count: int)
            
            #expect(hDivider1.count == int)
            #expect(hDivider2.count == int)
        }
        
        @Test("Is the style set by the lineStyle function applied to the header variable?", arguments: LineStyle.allCases)
        func lineStyleFuncTesting(
            lineStyle: LineStyle
        ) async throws {
            let hDivider = Divider(1).lineStyle(lineStyle)
            
            #expect(lineStyle == .default ? hDivider.character == "-" : hDivider.character == "=")
        }
        
        @Test("Is the color set by the forgroundColor function applied to the header variable?", arguments: allColors)
        func forgroundColorFuncTesting(
            color: Color
        ) async throws {
            let hDivider = Divider(1).forgroundColor(color).forgroundColor(color)
            
            #expect(hDivider.header == "\u{001B}[3\(color.ansi)m\u{001B}[3\(color.ansi)m")
        }
        
        @Test("Is the color set by the background function applied to the header variable?", arguments: allColors)
        func backgroundFuncTesting(
            color: Color
        ) async throws {
            let hDivider = Divider(1).background(color).background(color)
            
            #expect(hDivider.header == "\u{001B}[4\(color.ansi)m\u{001B}[4\(color.ansi)m")
        }
        
        @Test("Is the thickness set by the bold function applied to the header variable?")
        func boldFuncTesting() async throws {
            let hDivider1 = Divider(1).bold()
            let hDivider2 = Divider(1).bold(true)
            let hDivider3 = Divider(1).bold(false)
            
            #expect(hDivider1.header == "\u{001B}[1m")
            #expect(hDivider2.header == "\u{001B}[1m")
            #expect(hDivider3.header.isEmpty)
        }
        
        @Test("Is the thickness set by the fontWeight function applied to the header variable?", arguments: Weight.allCases)
        func fontWeightFuncTesting(
            weight: Weight
        ) async throws {
            let hDivider = Divider(1).fontWeight(weight)
            
            if weight == .default {
                #expect(hDivider.header.isEmpty)
            } else {
                #expect(hDivider.header == "\u{001B}[\(weight.rawValue)m")
            }
        }
        
        @Test("Is the style set by the blink function applied to the header variable?", arguments: BlinkStyle.allCases)
        func blinkFuncTesting(
            blink: BlinkStyle
        ) async throws {
            let hDivider = Divider(1).blink(blink)
            
            if blink == .none {
                #expect(hDivider.header.isEmpty)
            } else {
                #expect(hDivider.header == "\u{001B}[\(blink.rawValue)m")
            }
        }
        
        @Test("Is the style set by the hidden function applied to the header variable?")
        func hiddenFuncTesting() async throws {
            let hDivider1 = Divider(1).hidden()
            let hDivider2 = Divider(1).hidden(true)
            let hDivider3 = Divider(1).hidden(false)
            
            #expect(hDivider1.header == "\u{001B}[8m")
            #expect(hDivider2.header == "\u{001B}[8m")
            #expect(hDivider3.header.isEmpty)
        }

    }
}

@Suite("Spacer Testing",.tags(.spacer))
struct SpacerTests {
    @Suite(.tags(.normalBehavior))
    struct NormalBehavior {
        @Test("Is the value of the header variable correct when initialized?", arguments: [(randomStrings, randomInt)])
        func headerVariableInitialValueTesting(
            string: String,
            int: Int
        ) async throws {
            let spacer1 = Spacer(int)
            let spacer2 = Spacer()
            let spacer3 = Spacer(header: string, count: int)
            
            #expect(spacer1.header.isEmpty)
            #expect(spacer2.header.isEmpty)
            #expect(spacer3.header == string)
        }
        
        @Test("Is the value of the count variable correct when initialized?", arguments: [(randomStrings, randomInt)])
        func countVariableInitialValueTesting(
            string: String,
            int: Int
        ) async throws {
            let spacer1 = Spacer(int)
            let spacer2 = Spacer()
            let spacer3 = Spacer(header: string, count: int)
            
            #expect(spacer1.count == int)
            #expect(spacer2.count == 1)
            #expect(spacer3.count == int)
        }
        
        @Test("Is the color set by the background function applied to the header variable?", arguments: allColors)
        func backgroundFuncTesting(
            color: Color
        ) async throws {
            let spacer = Spacer().background(color).background(color)
            
            #expect(spacer.header == "\u{001B}[4\(color.ansi)m\u{001B}[4\(color.ansi)m")
        }
        
    }
}

@Suite("Emoticon Testing",.tags(.emotion))
struct EmoticonTests {
    @Suite(.tags(.normalBehavior))
    struct NormalBehavior {
        @Test("Is the value of the header variable correct when initialized?", arguments: [randomStrings])
        func headerVariableInitialValueTesting(
            string: String
        ) async throws {
            let emoticon1 = Emoticon()
            let emoticon2 = Emoticon(eye: .default, mouth: .default)
            let emoticon3 = Emoticon(eye: .default, nose: .none, mouth: .default)
            let emoticon4 = Emoticon(header: string, content: string)
            
            #expect(emoticon1.header.isEmpty)
            #expect(emoticon2.header.isEmpty)
            #expect(emoticon3.header.isEmpty)
            #expect(emoticon4.header == randomStrings)
        }
        
        @Test("Is the value of the content variable correct when initialized?", arguments:  [(randomStrings, randomInt, randomCharacter)])
        func contentVariableInitialValueTesting(
            string: String,
            int: Int,
            character: Character
        ) async throws {
            let emoticon1 = Emoticon()
            let emoticon2 = Emoticon(eye: .default, mouth: .default)
            let emoticon3 = Emoticon(eye: .default, nose: .none, mouth: .default)
            let emoticon4 = Emoticon(header: string, content: string)
            
            #expect(emoticon1.content == "\(EyesStyle.default.rawValue)\(NoseStyle.none.rawValue)\(MouthStyle.default.rawValue)")
            #expect(emoticon2.content == "\(EyesStyle.default.rawValue)\(NoseStyle.none.rawValue)\(MouthStyle.default.rawValue)")
            #expect(emoticon3.content == "\(EyesStyle.default.rawValue)\(NoseStyle.none.rawValue)\(MouthStyle.default.rawValue)")
            #expect(emoticon4.content == randomStrings)
        }
        
        @Test("Is the color set by the forgroundColor function applied to the header variable?", arguments: allColors)
        func forgroundColorFuncTesting(
            color: Color
        ) async throws {
            let emoticon = Emoticon().forgroundColor(color).forgroundColor(color)
            
            #expect(emoticon.header == "\u{001B}[3\(color.ansi)m\u{001B}[3\(color.ansi)m")
        }
        
        @Test("Is the color set by the background function applied to the header variable?", arguments: allColors)
        func backgroundFuncTesting(
            color: Color
        ) async throws {
            let emoticon = Emoticon().background(color).background(color)
            
            #expect(emoticon.header == "\u{001B}[4\(color.ansi)m\u{001B}[4\(color.ansi)m")
        }
        
        @Test("Is the thickness set by the bold function applied to the header variable?")
        func boldFuncTesting() async throws {
            let emoticon1 = Emoticon().bold()
            let emoticon2 = Emoticon().bold(true)
            let emoticon3 = Emoticon().bold(false)
            
            #expect(emoticon1.header == "\u{001B}[1m")
            #expect(emoticon2.header == "\u{001B}[1m")
            #expect(emoticon3.header.isEmpty)
        }
        
        @Test("Is the thickness set by the fontWeight function applied to the header variable?", arguments: Weight.allCases)
        func fontWeightFuncTesting(
            weight: Weight
        ) async throws {
            let emoticon = Emoticon().fontWeight(weight)
            
            if weight == .default {
                #expect(emoticon.header.isEmpty)
            } else {
                #expect(emoticon.header == "\u{001B}[\(weight.rawValue)m")
            }
        }
        
        @Test("Is the style set by the blink function applied to the header variable?", arguments: BlinkStyle.allCases)
        func blinkFuncTesting(
            blink: BlinkStyle
        ) async throws {
            let emoticon = Emoticon().blink(blink)
            
            if blink == .none {
                #expect(emoticon.header.isEmpty)
            } else {
                #expect(emoticon.header == "\u{001B}[\(blink.rawValue)m")
            }
        }
        
        @Test("Is the style set by the hidden function applied to the header variable?")
        func hiddenFuncTesting() async throws {
            let emoticon1 = Emoticon().hidden()
            let emoticon2 = Emoticon().hidden(true)
            let emoticon3 = Emoticon().hidden(false)
            
            #expect(emoticon1.header == "\u{001B}[8m")
            #expect(emoticon2.header == "\u{001B}[8m")
            #expect(emoticon3.header.isEmpty)
        }

    }
}

@Suite("HStack / VStack Layout Testing")
struct StackLayoutTests {
    @Test("HStack of Texts produces correct size")
    func hstackMeasure() {
        let stack = HStack(spacing: 1) {
            Text("AB")
            Text("CD")
        }
        let size = stack.measure()
        // "AB" = 2 cols, spacing = 1, "CD" = 2 cols → width 5, height 1
        #expect(size.width == 5)
        #expect(size.height == 1)
    }

    @Test("VStack of Texts produces correct size")
    func vstackMeasure() {
        let stack = VStack {
            Text("Hello")
            Text("Hi")
        }
        let size = stack.measure()
        // width = max(5, 2) = 5, height = 1 + 1 = 2
        #expect(size.width == 5)
        #expect(size.height == 2)
    }

    @Test("VStack { HStack { VStack { HStack } } } — deep nesting does not crash")
    func deepNestedStack() {
        let nested = VStack {
            HStack(spacing: 1) {
                VStack {
                    Text("A")
                    Text("B")
                }
                Text("|")
                VStack {
                    HStack(spacing: 1) {
                        Text("C")
                        Text("D")
                    }
                    HStack(spacing: 1) {
                        Text("E")
                        Text("F")
                    }
                }
            }
            Text("---bottom---")
        }
        let size = nested.measure()
        // Should produce a valid non-zero size without crashing
        #expect(size.width > 0)
        #expect(size.height > 0)
    }

    @Test("HStack renderString contains child text in order")
    func hstackRenderString() {
        let stack = HStack {
            Text("Left")
            Text("Right")
        }
        let s = stack.renderString()
        let plain = s.replacingOccurrences(of: "\u{001B}[0m", with: "")
        #expect(plain.contains("Left"))
        #expect(plain.contains("Right"))
        // Left must appear before Right
        let leftIdx = plain.range(of: "Left")!.lowerBound
        let rightIdx = plain.range(of: "Right")!.lowerBound
        #expect(leftIdx < rightIdx)
    }

    @Test("HStack with Divider renders vertical bar between children")
    func hstackDividerRendersVerticalBar() {
        let stack = HStack(spacing: 1) {
            Text("Left")
            Divider()
            Text("Right")
        }
        let s = stack.renderString()
        // Strip ANSI escape sequences to get plain text
        var plain = ""
        var i = s.startIndex
        while i < s.endIndex {
            if s[i] == "\u{001B}" {
                i = s.index(after: i)
                while i < s.endIndex {
                    let c = s[i]; i = s.index(after: i)
                    if c == "m" { break }
                }
            } else {
                plain.append(s[i]); i = s.index(after: i)
            }
        }
        #expect(plain.contains("|"))
        #expect(plain.contains("Left"))
        #expect(plain.contains("Right"))
    }

    @Test("VStack with Divider renders horizontal line between children")
    func vstackDividerRendersHorizontalLine() {
        let stack = VStack {
            Text("Above")
            Divider(5)
            Text("Below")
        }
        // Strip all ANSI escape sequences before checking plain text content.
        let raw = stack.renderString()
        let plain = raw.replacingOccurrences(of: "\u{001B}\\[[^m]*m", with: "", options: .regularExpression)
        #expect(plain.contains("-----"))
        #expect(plain.contains("Above"))
        #expect(plain.contains("Below"))
    }

    @Test("VStack trailing alignment offsets shorter row")
    func vstackTrailingAlignment() {
        let canvas = TerminalCanvas(width: 0, height: 0)
        let stack = VStack(alignment: .trailing) {
            Text("Hi")        // 2 chars
            Text("Hello")     // 5 chars — widest
        }
        stack.draw(into: canvas, at: .zero)
        let lines = canvas.toString().components(separatedBy: "\n")
        // First row ("Hi") must start at column 3 (5-2=3), so the first 3 cells
        // of the first line contain only spaces.
        let first = lines[0]
        let plain = first.replacingOccurrences(of: "\u{001B}[0m", with: "")
        #expect(plain.hasPrefix("   "))  // 3 leading spaces
    }
}

// MARK: - Intermediate-representation diff testing

/// Removes SGR (colour/style) escape sequences — those ending in `m` — while
/// leaving cursor-movement sequences (`\e[2K`, `\e[1B`, …) intact so tests can
/// reason about both the visible text and the diff control codes.
private func sgrStripped(_ s: String) -> String {
    s.replacingOccurrences(of: "\u{001B}\\[[0-9;?]*m", with: "", options: .regularExpression)
}

private func occurrences(of needle: String, in haystack: String) -> Int {
    guard !needle.isEmpty else { return 0 }
    var count = 0
    var range = haystack.startIndex..<haystack.endIndex
    while let found = haystack.range(of: needle, range: range) {
        count += 1
        range = found.upperBound..<haystack.endIndex
    }
    return count
}

/// The ANSI "erase entire line" sequence emitted once per rewritten line.
private let eraseLineCode = "\u{001B}[2K"

@Suite("IR Conditional & Diff Testing")
struct ConditionalDiffTests {

    /// A VStack whose middle row is chosen by an `if`/`else`; the surrounding
    /// rows and the overall width stay constant.
    private func sameWidthBranch(_ on: Bool) -> VStack {
        VStack {
            Text("top")
            if on { Text("AAAAA") } else { Text("BBBBB") }
            Text("bot")
        }
    }

    @Test("if/else selects the active branch in the lowered frame")
    func ifElseSelectsBranch() {
        let onFrame  = NodeLayout.frame(of: sameWidthBranch(true).makeNode())
        let offFrame = NodeLayout.frame(of: sameWidthBranch(false).makeNode())
        #expect(onFrame.lines.contains { sgrStripped($0) == "AAAAA" })
        #expect(!onFrame.lines.contains { sgrStripped($0) == "BBBBB" })
        #expect(offFrame.lines.contains { sgrStripped($0) == "BBBBB" })
        #expect(!offFrame.lines.contains { sgrStripped($0) == "AAAAA" })
    }

    @Test("Same-width if/else swap rewrites only the changed line")
    func sameWidthSwapRewritesOnlyChangedLine() {
        let a = NodeLayout.frame(of: sameWidthBranch(true).makeNode())
        let b = NodeLayout.frame(of: sameWidthBranch(false).makeNode())
        let diff = FrameDiff.inlineUpdate(from: a, to: b)

        // Exactly one line changed, so exactly one erase-line sequence.
        #expect(occurrences(of: eraseLineCode, in: diff) == 1)
        // The new content is emitted…
        #expect(sgrStripped(diff).contains("BBBBB"))
        // …and the unchanged surrounding rows are NOT rewritten (skipped).
        #expect(!sgrStripped(diff).contains("top"))
        #expect(!sgrStripped(diff).contains("bot"))
    }

    /// An HStack where the left VStack's width is driven by an `if`/`else`.
    /// Widening the left column must shift the divider and right column.
    private func widthPropagating(_ wide: Bool) -> HStack {
        HStack(spacing: 1) {
            VStack {
                Text("T")
                if wide { Text("wwwwwwww") } else { Text("s") }
            }
            Text("|")
            VStack {
                Text("R1")
                Text("R2")
            }
        }
    }

    @Test("Widening one column shifts siblings, and the diff redraws them")
    func widthChangePropagatesToSiblings() {
        let narrow = NodeLayout.frame(of: widthPropagating(false).makeNode())
        let wide   = NodeLayout.frame(of: widthPropagating(true).makeNode())

        // Row 0's left cell ("T") is textually unchanged, yet the whole row
        // differs because the right column shifted — exactly the propagation
        // the diff must catch.
        #expect(sgrStripped(narrow.lines[0]) != sgrStripped(wide.lines[0]))
        #expect(sgrStripped(narrow.lines[0]).contains("R1"))
        #expect(sgrStripped(wide.lines[0]).contains("R1"))

        let diff = FrameDiff.inlineUpdate(from: narrow, to: wide)
        // Both rows changed (row 0 shifted, row 1 shifted + text swapped).
        #expect(occurrences(of: eraseLineCode, in: diff) == 2)
        // The shifted right column is part of the rewritten output.
        #expect(sgrStripped(diff).contains("R1"))
    }

    /// A VStack whose row count is driven by an `if` (no `else`).
    private func rowCount(_ many: Bool) -> VStack {
        VStack {
            Text("a")
            Text("b")
            if many {
                Text("c")
                Text("d")
            }
        }
    }

    @Test("Shrinking the frame erases the rows that disappeared")
    func shrinkingFrameErasesExtraRows() {
        let tall  = NodeLayout.frame(of: rowCount(true).makeNode())   // 4 rows
        let short = NodeLayout.frame(of: rowCount(false).makeNode())  // 2 rows
        #expect(tall.lines.count == 4)
        #expect(short.lines.count == 2)

        let diff = FrameDiff.inlineUpdate(from: tall, to: short)
        // Rows "a"/"b" are unchanged (skipped); the two vanished rows are erased.
        #expect(occurrences(of: eraseLineCode, in: diff) == 2)
        #expect(!sgrStripped(diff).contains("a"))
    }

    @Test("Growing the frame appends the new rows")
    func growingFrameAppendsRows() {
        let short = NodeLayout.frame(of: rowCount(false).makeNode())  // 2 rows
        let tall  = NodeLayout.frame(of: rowCount(true).makeNode())   // 4 rows

        let diff = FrameDiff.inlineUpdate(from: short, to: tall)
        // Existing rows unchanged; the two appended rows are written (erased+drawn).
        #expect(occurrences(of: eraseLineCode, in: diff) == 2)
        #expect(sgrStripped(diff).contains("c"))
        #expect(sgrStripped(diff).contains("d"))
    }

    @Test("Full-screen diff also redraws only changed lines")
    func fullScreenDiffRedrawsChangedLines() {
        let a = NodeLayout.frame(of: sameWidthBranch(true).makeNode())
        let b = NodeLayout.frame(of: sameWidthBranch(false).makeNode())
        let diff = FrameDiff.fullScreenUpdate(from: a, to: b)
        // Only the middle line is repositioned & rewritten.
        #expect(occurrences(of: eraseLineCode, in: diff) == 1)
        #expect(sgrStripped(diff).contains("BBBBB"))
        #expect(!sgrStripped(diff).contains("top"))
    }
}

@Suite("Hidden Blanking Testing")
struct HiddenBlankingTests {

    @Test("hidden() blanks the glyphs but keeps the same width")
    func hiddenBlanksGlyphsPreservingWidth() {
        let shown  = NodeLayout.frame(of: Text("Hello").makeNode())
        let hidden = NodeLayout.frame(of: Text("Hello").hidden().makeNode())
        // Same measured size — the layout is untouched.
        #expect(NodeLayout.measure(Text("Hello").makeNode())
                == NodeLayout.measure(Text("Hello").hidden().makeNode()))
        // Original text is visible; hidden text is the same width, all spaces.
        #expect(sgrStripped(shown.lines[0]) == "Hello")
        #expect(sgrStripped(hidden.lines[0]) == "     ")   // 5 spaces, no glyphs
    }

    @Test("A hidden field inside an HStack does not shift its neighbours")
    func hiddenKeepsNeighboursInPlace() {
        func row(_ hide: Bool) -> HStack {
            HStack(spacing: 1) {
                Text("name:")
                Text("secret").hidden(hide)
                Text("<")
            }
        }
        let shown  = NodeLayout.frame(of: row(false).makeNode())
        let hidden = NodeLayout.frame(of: row(true).makeNode())

        // The trailing "<" sits at the exact same column in both states,
        // because the hidden field still occupies "secret".count columns.
        let shownPlain  = sgrStripped(shown.lines[0])
        let hiddenPlain = sgrStripped(hidden.lines[0])
        #expect(shownPlain  == "name: secret <")
        #expect(hiddenPlain == "name:        <")   // "secret" → 6 spaces, "<" unmoved
        #expect(shownPlain.count == hiddenPlain.count)
    }

    @Test("hidden() blanks a wide (2-column) character to two spaces")
    func hiddenBlanksWideCharacter() {
        // A full-width character ("あ") occupies two columns, so hiding it must
        // emit two spaces to preserve the width.
        #expect(NodeLayout.blankedGlyphs(of: "あ") == "  ")
        #expect(NodeLayout.blankedGlyphs(of: "ab") == "  ")
        // End to end: the hidden wide glyph leaves the trailing bar two columns in.
        let hidden = NodeLayout.frame(of: HStack { Text("あ").hidden(); Text("|") }.makeNode())
        #expect(sgrStripped(hidden.lines[0]) == "  |")
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

// MARK: - Line clipping (wrap-safety) testing

@Suite("Line Clipping Testing")
struct LineClippingTests {
    private func visibleWidth(_ s: String) -> Int {
        TextMetrics.visibleWidth(TextMetrics.stripANSI(s))
    }

    @Test("Clips a plain line to the column limit")
    func clipsPlain() {
        let clipped = TextMetrics.truncate(String(repeating: "X", count: 40), toColumns: 20)
        #expect(visibleWidth(clipped) == 20)
    }

    @Test("A line at or below the limit is left unchanged")
    func keepsShort() {
        let s = "\u{001B}[32mHello\u{001B}[0m"
        #expect(TextMetrics.truncate(s, toColumns: 20) == s)
    }

    @Test("Escape sequences don't count toward the width and a reset is appended when cut")
    func preservesANSIAndResets() {
        let styled = "\u{001B}[32m" + String(repeating: "X", count: 40) + "\u{001B}[0m"
        let clipped = TextMetrics.truncate(styled, toColumns: 20)
        #expect(visibleWidth(clipped) == 20)
        #expect(clipped.hasPrefix("\u{001B}[32m"))
        #expect(clipped.hasSuffix("\u{001B}[0m"))
    }

    @Test("A wide (2-column) glyph is dropped rather than split at the boundary")
    func doesNotSplitWideGlyph() {
        // 15 full-width characters = 30 columns; clipping to 21 keeps 10 (= 20
        // columns) and drops the 11th rather than emitting a half-width cell.
        let clipped = TextMetrics.truncate(String(repeating: "あ", count: 15), toColumns: 21)
        #expect(visibleWidth(clipped) == 20)
    }
}

@Suite("Grapheme Width Testing")
struct GraphemeWidthTests {
    @Test("ASCII is one column per character")
    func ascii() {
        #expect(TextMetrics.visibleWidth("Hello") == 5)
    }

    @Test("CJK and full-width glyphs are two columns each")
    func wideCJK() {
        #expect(TextMetrics.visibleWidth("あ") == 2)
        #expect(TextMetrics.visibleWidth("日本語") == 6)
        #expect(TextMetrics.visibleWidth("Ａ") == 2)   // full-width A
        #expect(TextMetrics.visibleWidth("　") == 2)   // ideographic space
    }

    @Test("Emoji count as two columns, including presentation and VS16 forms")
    func emoji() {
        #expect(TextMetrics.width(of: "😀") == 2)
        #expect(TextMetrics.width(of: "❤️") == 2)   // U+2764 + VS16
        #expect(TextMetrics.visibleWidth("a😀b") == 4)
    }

    @Test("A ZWJ family and a flag are single double-width clusters")
    func compoundEmoji() {
        #expect(TextMetrics.width(of: "👨‍👩‍👧‍👦") == 2)   // ZWJ family
        #expect(TextMetrics.width(of: "🇯🇵") == 2)          // regional-indicator flag
    }

    @Test("Combining marks compose onto their base and add no width")
    func combiningMarks() {
        // "e" + combining acute accent is one grapheme cluster, one column.
        #expect(TextMetrics.visibleWidth("e\u{0301}") == 1)
        #expect(TextMetrics.visibleWidth("café") == 4)
    }
}

@Suite("Frame & Wrapping Testing")
struct FrameWrappingTests {
    private func plainLines(_ node: RenderNode) -> [String] {
        NodeLayout.frame(of: node).lines.map { TextMetrics.stripANSI($0) }
    }

    @Test("Word wrap breaks at spaces and never exceeds the column budget")
    func wordWrap() {
        let lines = NodeLayout.wrap("The quick brown fox jumps", toColumns: 10)
        for line in lines { #expect(TextMetrics.visibleWidth(line) <= 10) }
        #expect(lines.count >= 3)
        // Words are kept intact (no mid-word split at a boundary here).
        #expect(lines.allSatisfy { !$0.hasPrefix(" ") })
    }

    @Test("A long word with no spaces is hard-broken to the width")
    func hardBreak() {
        let lines = NodeLayout.wrap("abcdefghijklmnop", toColumns: 5)
        #expect(lines.count == 4)
        for line in lines { #expect(TextMetrics.visibleWidth(line) <= 5) }
    }

    @Test("Wide (CJK) glyphs wrap without splitting a two-column cell")
    func wideWrap() {
        let lines = NodeLayout.wrap("あいうえおかきくけこ", toColumns: 7)
        for line in lines { #expect(TextMetrics.visibleWidth(line) <= 7) }
    }

    @Test("A width-constrained frame wraps its text onto multiple rows")
    func frameWraps() {
        let node = Text("The quick brown fox jumps over the lazy dog")
            .frame(width: 20, alignment: .topLeading)
            .makeNode()
        let lines = plainLines(node)
        #expect(lines.count > 1)
        for line in lines { #expect(TextMetrics.visibleWidth(line) <= 20) }
    }

    @Test("lineLimit caps the visual line count and ends with an ellipsis")
    func lineLimitEllipsis() {
        let node = Text("The quick brown fox jumps over the lazy dog")
            .frame(width: 20, alignment: .topLeading)
            .lineLimit(2)
            .makeNode()
        let lines = plainLines(node)
        #expect(lines.count == 2)
        #expect(lines.last?.contains("…") == true)
    }

    @Test("A fixed frame pads a smaller child to its width and height")
    func fixedFramePads() {
        let node = Text("hi").frame(width: 10, height: 3, alignment: .center).makeNode()
        let size = NodeLayout.measure(node)
        #expect(size.width == 10)
        #expect(size.height == 3)
    }

    @Test("A frame clips content taller than its fixed height")
    func fixedFrameClips() {
        let tall = VStack(alignment: .leading) {
            Text("one"); Text("two"); Text("three"); Text("four")
        }
        let node = tall.frame(height: 2, alignment: .topLeading).makeNode()
        let lines = plainLines(node).filter { !$0.isEmpty }
        #expect(lines.count <= 2)
        #expect(lines.first == "one")
    }

    @Test("A scroll node shows a height-row window offset from the top")
    func scrollWindow() {
        let content = RenderNode.vstack(alignment: .leading, spacing: 0, children:
            (0..<10).map { RenderNode.text(header: "", contents: ["Row \($0)"]) })
        // Offset 3, viewport 4, no scrollbar → rows 3..6.
        let node = RenderNode.scroll(offset: 3, height: 4, thumb: nil, track: nil, child: content)
        let lines = plainLines(node).filter { !$0.isEmpty }
        #expect(lines == ["Row 3", "Row 4", "Row 5", "Row 6"])
        // The viewport height is fixed regardless of content height.
        #expect(NodeLayout.measure(node).height == 4)
    }

    @Test("A scroll offset past the end is clamped to the last window")
    func scrollClampsAtEnd() {
        let content = RenderNode.vstack(alignment: .leading, spacing: 0, children:
            (0..<5).map { RenderNode.text(header: "", contents: ["L\($0)"]) })
        let node = RenderNode.scroll(offset: 99, height: 3, thumb: nil, track: nil, child: content)
        let lines = plainLines(node).filter { !$0.isEmpty }
        #expect(lines == ["L2", "L3", "L4"])
    }
}

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

// MARK: - ProgressView graceful degradation

@Suite("ProgressView Degradation Testing")
struct ProgressViewDegradationTests {
    private func plain(_ v: some View) -> String {
        TextMetrics.stripANSI(v.renderString())
    }

    private func config(width: Int, label: String = "") -> ProgressViewStyleConfiguration {
        ProgressViewStyleConfiguration(
            fractionCompleted: 0.5,
            width: width,
            filledCharacter: "\u{2588}",
            emptyCharacter: "\u{2591}",
            label: label
        )
    }

    @Test("Bar keeps its gauge when there is room for it")
    func barShowsGauge() {
        let out = plain(BarProgressViewStyle().makeBody(configuration: config(width: 10)))
        #expect(out.contains("["))
        #expect(out.contains("50%"))
    }

    @Test("Bar collapses to a spinner glyph plus the label when width runs out")
    func barCollapsesToSpinner() {
        let out = plain(BarProgressViewStyle().makeBody(configuration: config(width: 0, label: "Build")))
        #expect(!out.contains("["))
        #expect(!out.contains("\u{2588}"))
        #expect(out.contains("Build"))
        // The leading glyph is one of the spinner frames.
        #expect(ProgressSpinner.frames.contains(out.first!))
    }

    @Test("A collapsed-width bar with no label is a single spinner glyph")
    func negativeWidthIsBareSpinner() {
        let out = plain(BarProgressViewStyle().makeBody(configuration: config(width: -3)))
        #expect(!out.contains("["))
        #expect(out.count == 1)
        #expect(ProgressSpinner.frames.contains(out.first!))
    }
}

// MARK: - TextField input testing

/// Reference box so a `Binding`'s get/set closures stay `@Sendable`-safe.
private final class StringBox: @unchecked Sendable {
    var value: String
    init(_ value: String) { self.value = value }
}

/// Boolean equivalent of ``StringBox`` for ``Toggle`` bindings.
private final class BoolBox: @unchecked Sendable {
    var value: Bool
    init(_ value: Bool) { self.value = value }
}

/// Integer equivalent of ``StringBox`` for ``Picker`` bindings.
private final class IntBox: @unchecked Sendable {
    var value: Int
    init(_ value: Int) { self.value = value }
}

/// Optional-integer box for ``List`` selection bindings.
private final class OptionalIntBox: @unchecked Sendable {
    var value: Int?
    init(_ value: Int?) { self.value = value }
}

@Suite("TextField Input Testing")
struct TextFieldInputTests {

    // MARK: TextFieldEditor (pure editing model, driven by commands)

    @Test("Insert commands add characters at the cursor and advance it")
    func typingInserts() {
        var result = TextFieldEditor.Result(text: "", cursor: 0)
        for ch in "Hi" {
            result = TextFieldEditor.apply(.insert(ch), to: result.text, cursor: result.cursor)
        }
        #expect(result.text == "Hi")
        #expect(result.cursor == 2)
    }

    @Test("A character is inserted at the cursor, not appended")
    func insertsAtCursor() {
        let result = TextFieldEditor.apply(.insert("X"), to: "ac", cursor: 1)
        #expect(result.text == "aXc")
        #expect(result.cursor == 2)
    }

    @Test("deleteBackward removes the character before the cursor")
    func backspaceDeletes() {
        let result = TextFieldEditor.apply(.deleteBackward, to: "Hi", cursor: 2)
        #expect(result.text == "H")
        #expect(result.cursor == 1)
    }

    @Test("Line-start/end and left/right move the cursor without editing")
    func cursorMovesOnly() {
        #expect(TextFieldEditor.apply(.moveToLineStart, to: "abc", cursor: 3).cursor == 0)
        #expect(TextFieldEditor.apply(.moveToLineEnd, to: "abc", cursor: 0).cursor == 3)
        #expect(TextFieldEditor.apply(.moveLeft, to: "abc", cursor: 2).cursor == 1)
        #expect(TextFieldEditor.apply(.moveRight, to: "abc", cursor: 1).cursor == 2)
        #expect(TextFieldEditor.apply(.moveToLineStart, to: "abc", cursor: 3).text == "abc")
    }

    @Test("deleteToLineStart / deleteToLineEnd / deleteWordBackward kill text")
    func killEdits() {
        #expect(TextFieldEditor.apply(.deleteToLineStart, to: "hello world", cursor: 6).text == "world")
        #expect(TextFieldEditor.apply(.deleteToLineStart, to: "hello world", cursor: 6).cursor == 0)
        #expect(TextFieldEditor.apply(.deleteToLineEnd, to: "hello world", cursor: 5).text == "hello")
        #expect(TextFieldEditor.apply(.deleteWordBackward, to: "foo bar", cursor: 7).text == "foo ")
        #expect(TextFieldEditor.apply(.deleteWordBackward, to: "foo bar ", cursor: 8).text == "foo ")
    }

    // MARK: KeyDecoder (control-key line editing matches the terminal norm)

    @Test("Emacs/readline control keys decode to the matching editing events")
    func decodesControlKeys() {
        var decoder = KeyDecoder()
        #expect(decoder.feed([0x01]) == [.home])              // Ctrl-A
        #expect(decoder.feed([0x05]) == [.end])               // Ctrl-E
        #expect(decoder.feed([0x02]) == [.left])              // Ctrl-B
        #expect(decoder.feed([0x06]) == [.right])             // Ctrl-F
        #expect(decoder.feed([0x04]) == [.delete])            // Ctrl-D
        #expect(decoder.feed([0x0B]) == [.deleteToEnd])       // Ctrl-K
        #expect(decoder.feed([0x15]) == [.deleteToStart])     // Ctrl-U
        #expect(decoder.feed([0x17]) == [.deleteWordBackward]) // Ctrl-W
    }

    // MARK: TextInputKeymap (the style that maps keys → commands)

    @Test("Shared keys map to the same command regardless of keymap")
    func sharedKeymap() {
        #expect(SingleLineKeymap().command(for: .character("a")) == .insert("a"))
        #expect(SingleLineKeymap().command(for: .backspace) == .deleteBackward)
        #expect(MultiLineKeymap().command(for: .character("a")) == .insert("a"))
        #expect(SingleLineKeymap().command(for: .tab) == .focusNext)
    }

    @Test("Return and up/down differ between the single-line and multi-line keymaps")
    func contextualKeymap() {
        #expect(SingleLineKeymap().command(for: .enter) == .submit)
        #expect(SingleLineKeymap().command(for: .up) == .ignore)
        #expect(MultiLineKeymap().command(for: .enter) == .newline)
        #expect(MultiLineKeymap().command(for: .up) == .moveUp)
        #expect(MultiLineKeymap().command(for: .down) == .moveDown)
    }
}

// MARK: - TextEditor (multi-line) input testing

@Suite("TextEditor Input Testing")
struct TextEditorInputTests {
    @Test("The newline command splits the line")
    func insertNewline() {
        let r = TextFieldEditor.apply(.newline, to: "ab", cursor: 2)
        #expect(r.text == "ab\n")
        #expect(r.cursor == 3)
    }

    @Test("Line-start/end are line-local across multiple lines")
    func lineLocalHomeEnd() {
        // "abc\ndef": cursor 5 sits on the 2nd line (between d and e).
        #expect(TextFieldEditor.apply(.moveToLineStart, to: "abc\ndef", cursor: 5).cursor == 4)
        #expect(TextFieldEditor.apply(.moveToLineEnd, to: "abc\ndef", cursor: 5).cursor == 7)
    }

    @Test("moveUp / moveDown go to the same column on the adjacent line")
    func verticalMovement() {
        // "abc\nde": cursor 6 (end of 2nd line, column 2) → up to column 2 of line 1.
        #expect(TextFieldEditor.apply(.moveUp, to: "abc\nde", cursor: 6).cursor == 2)
        // "abc\ndef": cursor 1 (line 1, column 1) → down to column 1 of line 2.
        #expect(TextFieldEditor.apply(.moveDown, to: "abc\ndef", cursor: 1).cursor == 5)
    }

    @Test("moveUp on the first line and moveDown on the last line are no-ops")
    func verticalEdges() {
        #expect(TextFieldEditor.apply(.moveUp, to: "abc\ndef", cursor: 1).cursor == 1)
        #expect(TextFieldEditor.apply(.moveDown, to: "abc\ndef", cursor: 5).cursor == 5)
    }

    @Test("Indent inserts spaces at the cursor; dedent removes leading spaces")
    func indentDedent() {
        let indented = TextFieldEditor.apply(.indent, to: "ab", cursor: 2)
        #expect(indented.text == "ab    ")       // 4 spaces
        #expect(indented.cursor == 6)

        let dedented = TextFieldEditor.apply(.dedent, to: "    x", cursor: 5)
        #expect(dedented.text == "x")            // 4 leading spaces removed
        #expect(dedented.cursor == 1)
    }

    @Test("By default the multi-line keymap maps Tab to focus movement (Textual TextArea)")
    func multiLineTabMovesFocus() {
        #expect(MultiLineKeymap().command(for: .tab) == .focusNext)
        #expect(MultiLineKeymap().command(for: .backTab) == .focusPrevious)
        // A single-line field also uses Tab for focus movement.
        #expect(SingleLineKeymap().command(for: .tab) == .focusNext)
    }

    @Test("The code-editor keymap maps Tab to indent (Textual TextArea.code_editor)")
    func multiLineTabIndentsWhenOptedIn() {
        let code = MultiLineKeymap(indentsWithTab: true)
        #expect(code.command(for: .tab) == .indent)
        #expect(code.command(for: .backTab) == .dedent)
        // Everything else matches the default multi-line keymap.
        #expect(code.command(for: .enter) == .newline)
    }
}

// MARK: - Focus coordinator routing (shared singleton → serialized)

/// These tests drive the process-wide ``FocusCoordinator/shared`` singleton, so
/// they must not run in parallel with one another.
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

// MARK: - Toggle style testing

@Suite("Toggle Style Testing")
struct ToggleStyleTests {
    private func plain(_ v: some View) -> String {
        TextMetrics.stripANSI(v.renderString())
    }
    private func config(_ isOn: Bool, focused: Bool = false, label: String = "OK") -> ToggleStyleConfiguration {
        ToggleStyleConfiguration(label: label, isOn: isOn, isFocused: focused)
    }

    @Test("Yes/No style brackets the selected side")
    func yesNo() {
        #expect(plain(YesNoToggleStyle().makeBody(configuration: config(true))).contains("[Yes]"))
        #expect(plain(YesNoToggleStyle().makeBody(configuration: config(false))).contains("[No]"))
    }

    @Test("Checkbox style marks the box when on")
    func checkbox() {
        #expect(plain(CheckboxToggleStyle().makeBody(configuration: config(true))).contains("[x]"))
        #expect(plain(CheckboxToggleStyle().makeBody(configuration: config(false))).contains("[ ]"))
    }

    @Test("Switch style shows an explicit ON/OFF word plus the knob side")
    func switchStyle() {
        let on = plain(SwitchToggleStyle().makeBody(configuration: config(true)))
        let off = plain(SwitchToggleStyle().makeBody(configuration: config(false)))
        #expect(on.contains("ON"))
        #expect(on.contains("──●"))
        #expect(off.contains("OFF"))
        #expect(off.contains("●──"))
    }

    @Test("Prompt style shows a [y/n] hint and echoes the typed answer")
    func promptStyle() {
        let yes = plain(PromptToggleStyle().makeBody(configuration: config(true)))
        let no = plain(PromptToggleStyle().makeBody(configuration: config(false)))
        #expect(yes.contains("[y/n]"))
        #expect(yes.contains("y"))
        #expect(no.contains("n"))
    }
}

// MARK: - Picker style testing

@Suite("Picker Style Testing")
struct PickerStyleTests {
    private func plain(_ v: some View) -> String {
        TextMetrics.stripANSI(v.renderString())
    }
    private func config(_ selected: Int) -> PickerStyleConfiguration {
        PickerStyleConfiguration(label: "Color", options: ["Red", "Green", "Blue"], selectedIndex: selected, isFocused: false)
    }

    @Test("Inline style shows the selected option between arrows")
    func inline() {
        let out = plain(InlinePickerStyle().makeBody(configuration: config(1)))
        #expect(out.contains("‹"))
        #expect(out.contains("Green"))
        #expect(out.contains("›"))
    }

    @Test("Segmented style brackets the selected option")
    func segmented() {
        let out = plain(SegmentedPickerStyle().makeBody(configuration: config(2)))
        #expect(out.contains("[Blue]"))
        #expect(out.contains("Red"))
    }

    @Test("List style marks the selected row and lists every option")
    func list() {
        let out = plain(ListPickerStyle().makeBody(configuration: config(0)))
        #expect(out.contains("❯"))
        #expect(out.contains("Red"))
        #expect(out.contains("Green"))
        #expect(out.contains("Blue"))
    }

    @Test("selection returns the option at the selected index")
    func selectionAccessor() {
        #expect(config(1).selection == "Green")
    }

    @Test("List style renders a visible focus change")
    func listReflectsFocus() {
        let focused = PickerStyleConfiguration(label: "Color", options: ["Red", "Green", "Blue"], selectedIndex: 0, isFocused: true)
        let blurred = PickerStyleConfiguration(label: "Color", options: ["Red", "Green", "Blue"], selectedIndex: 0, isFocused: false)
        // Styling (colour/bold) differs, so the raw escape output must differ…
        #expect(ListPickerStyle().makeBody(configuration: focused).renderString()
                != ListPickerStyle().makeBody(configuration: blurred).renderString())
        // …and the focused header carries the ">" marker.
        #expect(plain(ListPickerStyle().makeBody(configuration: focused)).contains("> Color"))
    }
}
#endif
