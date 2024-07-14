import Testing
@testable import SwiftLI
import Foundation

extension Tag {
    @Tag static var general: Self
    @Tag static var viewProtocol: Self
    @Tag static var text: Self
    @Tag static var `break`: Self
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
            let text3 = Text(header: string, repeating: character, count: int, footer: false)
            let text4 = Text(header: string, content: string, footer: false)
            
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
            let text3 = Text(header: string, repeating: character, count: int, footer: false)
            let text4 = Text(header: string, content: string, footer: false)
            
            #expect(text1.content == string)
            #expect(text2.content == String(repeating: character, count: int))
            #expect(text3.content == String(repeating: character, count: int))
            #expect(text4.content == string)
        }
        
        @Test("Is the value of the footer variable correct when initialized?", arguments: [(randomStrings, randomInt, randomCharacter)])
        func footerVariableInitialValueTesting(
            string: String,
            int: Int,
            character: Character
        ) async throws {
            let text1 = Text(string)
            let text2 = Text(repeating: character, count: int)
            let text3 = Text(header: string, repeating: character, count: int, footer: false)
            let text4 = Text(header: string, content: string, footer: false)
            
            #expect(!text1.footer)
            #expect(!text2.footer)
            #expect(!text3.footer)
            #expect(!text4.footer)
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
        
        @Test("Is the style set by the newLine function applied to the header variable?")
        func newLineFuncTesting() async throws {
            let text1 = Text("").newLine()
            let text2 = Text("").newLine(true)
            let text3 = Text("").newLine(false)
            
            #expect(text1.footer)
            #expect(text2.footer)
            #expect(!text3.footer)
        }
    }
}

@Suite("Break Testing",.tags(.break))
struct BreakTests {
    @Suite(.tags(.normalBehavior))
    struct NormalBehavior {
        @Test("Is the value of the header variable correct when initialized?", arguments: [randomInt])
        func countVariableInitialValueTesting(
            int: Int
        ) async throws {
            let break1 = Break(int)
            let break2 = Break()
            
            #expect(break1.count == int)
            #expect(break2.count == 1)
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
            let group2 = Group(contents: [Text("")], footer: false)
            
            #expect(group1.contents.count == 1)
            #expect(group2.contents.count == 1)
        }
        
        @Test("Is the value of the footer variable correct when initialized?")
        func footerVariableInitialValueTesting() async throws {
            let group1 = Group {
            }
            let group2 = Group(contents: [], footer: false)
            
            #expect(!group1.footer)
            #expect(!group2.footer)
        }
        
        @Test("Is the style set by the strikethrough function applied to the header variable?")
        func newLineFuncTesting() async throws {
            let group1 = Group{}.newLine()
            let group2 = Group{}.newLine(true)
            let group3 = Group{}.newLine(false)
            
            #expect(group1.footer)
            #expect(group2.footer)
            #expect(!group3.footer)
        }
    }
}

@Suite("HDivider Testing")
struct HDividerTests {
    @Suite(.tags(.normalBehavior))
    struct NormalBehavior {
        @Test("Is the value of the header variable correct when initialized?", arguments: [(randomStrings, randomInt, randomCharacter)])
        func headerVariableInitialValueTesting(
            string: String,
            int: Int,
            character: Character
        ) async throws {
            let hDivider1 = HDivider(int)
            let hDivider2 = HDivider(header: string, character: character, count: int, footer: false)
            
            #expect(hDivider1.header.isEmpty)
            #expect(hDivider2.header == string)
        }
        
        @Test("Is the value of the character variable correct when initialized?", arguments: [(randomStrings, randomInt, randomCharacter)])
        func characterVariableInitialValueTesting(
            string: String,
            int: Int,
            character: Character
        ) async throws {
            let hDivider1 = HDivider(int)
            let hDivider2 = HDivider(header: string, character: character, count: int, footer: false)
            
            #expect(hDivider1.character == "-")
            #expect(hDivider2.character == randomCharacter)
        }
        
        @Test("Is the value of the count variable correct when initialized?", arguments: [(randomStrings, randomInt, randomCharacter)])
        func countVariableInitialValueTesting(
            string: String,
            int: Int,
            character: Character
        ) async throws {
            let hDivider1 = HDivider(int)
            let hDivider2 = HDivider(header: string, character: character, count: int, footer: false)
            
            #expect(hDivider1.count == int)
            #expect(hDivider2.count == int)
        }
        
        @Test("Is the value of the footer variable correct when initialized?", arguments: [(randomStrings, randomInt, randomCharacter)])
        func footerVariableInitialValueTesting(
            string: String,
            int: Int,
            character: Character
        ) async throws {
            let hDivider1 = HDivider(int)
            let hDivider2 = HDivider(header: string, character: character, count: int, footer: false)
            
            #expect(!hDivider1.footer)
            #expect(!hDivider2.footer)
        }
        
        @Test("Is the style set by the lineStyle function applied to the header variable?", arguments: LineStyle.allCases)
        func lineStyleFuncTesting(
            lineStyle: LineStyle
        ) async throws {
            let hDivider = HDivider(1).lineStyle(lineStyle)
            
            #expect(lineStyle == .default ? hDivider.character == "-" : hDivider.character == "=")
        }
        
        @Test("Is the color set by the forgroundColor function applied to the header variable?", arguments: allColors)
        func forgroundColorFuncTesting(
            color: Color
        ) async throws {
            let hDivider = HDivider(1).forgroundColor(color).forgroundColor(color)
            
            #expect(hDivider.header == "\u{001B}[3\(color.ansi)m\u{001B}[3\(color.ansi)m")
        }
        
        @Test("Is the color set by the background function applied to the header variable?", arguments: allColors)
        func backgroundFuncTesting(
            color: Color
        ) async throws {
            let hDivider = HDivider(1).background(color).background(color)
            
            #expect(hDivider.header == "\u{001B}[4\(color.ansi)m\u{001B}[4\(color.ansi)m")
        }
        
        @Test("Is the thickness set by the bold function applied to the header variable?")
        func boldFuncTesting() async throws {
            let hDivider1 = HDivider(1).bold()
            let hDivider2 = HDivider(1).bold(true)
            let hDivider3 = HDivider(1).bold(false)
            
            #expect(hDivider1.header == "\u{001B}[1m")
            #expect(hDivider2.header == "\u{001B}[1m")
            #expect(hDivider3.header.isEmpty)
        }
        
        @Test("Is the thickness set by the fontWeight function applied to the header variable?", arguments: Weight.allCases)
        func fontWeightFuncTesting(
            weight: Weight
        ) async throws {
            let hDivider = HDivider(1).fontWeight(weight)
            
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
            let hDivider = HDivider(1).blink(blink)
            
            if blink == .none {
                #expect(hDivider.header.isEmpty)
            } else {
                #expect(hDivider.header == "\u{001B}[\(blink.rawValue)m")
            }
        }
        
        @Test("Is the style set by the hidden function applied to the header variable?")
        func hiddenFuncTesting() async throws {
            let hDivider1 = HDivider(1).hidden()
            let hDivider2 = HDivider(1).hidden(true)
            let hDivider3 = HDivider(1).hidden(false)
            
            #expect(hDivider1.header == "\u{001B}[8m")
            #expect(hDivider2.header == "\u{001B}[8m")
            #expect(hDivider3.header.isEmpty)
        }

        @Test("Is the style set by the newLine function applied to the header variable?")
        func newLineFuncTesting() async throws {
            let hDivider1 = HDivider(1).newLine()
            let hDivider2 = HDivider(1).newLine(true)
            let hDivider3 = HDivider(1).newLine(false)
            
            #expect(hDivider1.footer)
            #expect(hDivider2.footer)
            #expect(!hDivider3.footer)
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
            let spacer3 = Spacer(header: string, count: int, footer: false)
            
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
            let spacer3 = Spacer(header: string, count: int, footer: false)
            
            #expect(spacer1.count == int)
            #expect(spacer2.count == 1)
            #expect(spacer3.count == int)
        }
        
        @Test("Is the value of the footer variable correct when initialized?")
        func footerVariableInitialValueTesting() async throws {
            let spacer1 = Spacer(1)
            let spacer2 = Spacer()
            let spacer3 = Spacer(header: "", count: 1, footer: false)
            
            #expect(!spacer1.footer)
            #expect(!spacer2.footer)
            #expect(!spacer3.footer)
        }
        
        @Test("Is the color set by the background function applied to the header variable?", arguments: allColors)
        func backgroundFuncTesting(
            color: Color
        ) async throws {
            let spacer = Spacer().background(color).background(color)
            
            #expect(spacer.header == "\u{001B}[4\(color.ansi)m\u{001B}[4\(color.ansi)m")
        }
        
        @Test("Is the style set by the newLine function applied to the header variable?")
        func newLineFuncTesting() async throws {
            let spacer1 = Spacer().newLine()
            let spacer2 = Spacer().newLine(true)
            let spacer3 = Spacer().newLine(false)
            
            #expect(spacer1.footer)
            #expect(spacer2.footer)
            #expect(!spacer3.footer)
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
            let emoticon4 = Emoticon(header: string, content: string, footer: false)
            
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
            let emoticon4 = Emoticon(header: string, content: string, footer: false)
            
            #expect(emoticon1.content == "\(EyesStyle.default.rawValue)\(NoseStyle.none.rawValue)\(MouthStyle.default.rawValue)")
            #expect(emoticon2.content == "\(EyesStyle.default.rawValue)\(NoseStyle.none.rawValue)\(MouthStyle.default.rawValue)")
            #expect(emoticon3.content == "\(EyesStyle.default.rawValue)\(NoseStyle.none.rawValue)\(MouthStyle.default.rawValue)")
            #expect(emoticon4.content == randomStrings)
        }
        
        @Test("Is the value of the footer variable correct when initialized?", arguments: [(randomStrings, randomInt, randomCharacter)])
        func footerVariableInitialValueTesting(
            string: String,
            int: Int,
            character: Character
        ) async throws {
            let emoticon1 = Emoticon()
            let emoticon2 = Emoticon(eye: .default, mouth: .default)
            let emoticon3 = Emoticon(eye: .default, nose: .none, mouth: .default)
            let emoticon4 = Emoticon(header: string, content: string, footer: false)
            
            #expect(!emoticon1.footer)
            #expect(!emoticon2.footer)
            #expect(!emoticon3.footer)
            #expect(!emoticon4.footer)
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

        @Test("Is the style set by the newLine function applied to the header variable?")
        func newLineFuncTesting() async throws {
            let emoticon1 = Emoticon().newLine()
            let emoticon2 = Emoticon().newLine(true)
            let emoticon3 = Emoticon().newLine(false)
            
            #expect(emoticon1.footer)
            #expect(emoticon2.footer)
            #expect(!emoticon3.footer)
        }
    }
}
