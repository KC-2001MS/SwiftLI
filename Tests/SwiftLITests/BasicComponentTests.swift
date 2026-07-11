//
//  BasicComponentTests.swift
//  SwiftLITests
//
//  Created by Keisuke Chinone on 2026/07/10.
//

#if swift(>=6.0)
import Testing
@_spi(RenderingInternals) @testable import SwiftLI
import Foundation

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
            let spacer1 = Spacer(minLength: int)
            let spacer2 = Spacer()
            let spacer3 = Spacer(header: string, minLength: int)

            #expect(spacer1.header.isEmpty)
            #expect(spacer2.header.isEmpty)
            #expect(spacer3.header == string)
        }

        @Test("Is the value of the minLength variable correct when initialized?", arguments: [(randomStrings, randomInt)])
        func minLengthVariableInitialValueTesting(
            string: String,
            int: Int
        ) async throws {
            let spacer1 = Spacer(minLength: int)
            let spacer2 = Spacer()
            let spacer3 = Spacer(header: string, minLength: int)

            #expect(spacer1.minLength == int)
            #expect(spacer2.minLength == 1)
            #expect(spacer3.minLength == int)
        }
        
        @Test("Is the color set by the background function applied to the header variable?", arguments: allColors)
        func backgroundFuncTesting(
            color: Color
        ) async throws {
            let spacer = Spacer().background(color).background(color)

            #expect(spacer.header == "\u{001B}[4\(color.ansi)m\u{001B}[4\(color.ansi)m")
        }

        @Test("A Spacer inside an HStack expands to the available width")
        func spacerExpandsInHStack() async throws {
            let row = HStack(spacing: 0) {
                Text("Left")
                Spacer()
                Text("Right")
            }
            let line = TextMetrics.stripANSI(row.renderString())
            #expect(line.hasPrefix("Left"))
            #expect(line.hasSuffix("Right"))
            // The spacer absorbs all leftover columns up to the top-level width.
            #expect(line.count == EnvironmentValues().maxWidth)
        }

        @Test("minLength keeps the floor when the row already fills the width")
        func spacerRespectsMinLength() async throws {
            let width = EnvironmentValues().maxWidth
            let long = String(repeating: "x", count: width)
            let row = HStack(spacing: 0) {
                Text(long)
                Spacer(minLength: 4)
                Text("R")
            }
            let line = TextMetrics.stripANSI(row.renderString())
            // No leftover space: the spacer stays at its minimum of 4 columns.
            #expect(line.count == width + 4 + 1)
        }

        @Test("A Spacer inside a VStack expands to the available height")
        func spacerVerticalExpansion() async throws {
            let column = VStack(alignment: .leading, spacing: 0) {
                Text("A")
                Spacer()
                Text("B")
            }
            let lines = TextMetrics.stripANSI(column.renderString()).components(separatedBy: "\n")
            // The spacer absorbs all leftover rows up to the top-level height,
            // pushing "B" to the bottom edge.
            #expect(lines.count == EnvironmentValues().maxHeight)
            #expect(lines.first?.hasPrefix("A") == true)
            #expect(lines.last?.hasPrefix("B") == true)
            #expect(lines[1].trimmingCharacters(in: .whitespaces).isEmpty)
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

@Suite("Link Testing")
struct LinkTests {
    @Test("A link measures only its label width, not the OSC 8 escape or URL")
    func linkWidthIsLabelOnly() {
        let node = Link("Apple", destination: "https://apple.com").makeNode()
        let size = NodeLayout.measure(node)
        #expect(size.width == TextMetrics.visibleWidth("Apple"))
        #expect(size.height == 1)
    }

    @Test("Stripping ANSI/OSC from a link leaves just the label")
    func linkStripsToLabel() {
        let out = NodeLayout.frame(of: Link("Apple", destination: "https://apple.com").makeNode()).lines
        #expect(out.map { TextMetrics.stripANSI($0) }.joined() == "Apple")
    }

    @Test("A link emits the OSC 8 open sequence carrying its destination")
    func linkEmitsOSC8() {
        let raw = NodeLayout.frame(of: Link("Apple", destination: "https://apple.com").makeNode()).lines.joined()
        #expect(raw.contains("\u{001B}]8;;https://apple.com\u{001B}\\"))
        // …and closes the link so it does not leak onto later cells.
        #expect(raw.contains("\u{001B}]8;;\u{001B}\\"))
    }
}

#endif
