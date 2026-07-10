//
//  TextTests.swift
//  SwiftLITests
//
//  Created by Keisuke Chinone on 2026/07/10.
//

#if swift(>=6.0)
import Testing
@_spi(RenderingInternals) @testable import SwiftLI
import Foundation

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

#endif
