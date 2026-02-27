#if swift(>=6.0)
import Testing
@testable import SwiftLI
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
            var views:  [View] {
                Text("")
                Text("")
                Text("")
            }
            
            #expect(views.count == 3)
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
        let s = stack.renderString()
        #expect(s.contains("-----"))
        #expect(s.contains("Above"))
        #expect(s.contains("Below"))
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
#endif
