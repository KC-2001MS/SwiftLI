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
        @Test("Is the value of the style variable correct when initialized?", arguments: [(randomStrings, randomInt, randomCharacter)])
        func styleVariableInitialValueTesting(
            string: String,
            int: Int,
            character: Character
        ) async throws {
            let style = TextStyle(foreground: .red, weight: .bold)
            let text1 = Text(string)
            let text2 = Text(repeating: character, count: int)
            let text3 = Text(style: style, repeating: character, count: int)
            let text4 = Text(style: style, content: string)

            #expect(text1.style.isPlain)
            #expect(text2.style.isPlain)
            #expect(text3.style == style)
            #expect(text4.style == style)
        }

        @Test("Is the value of the content variable correct when initialized?", arguments:  [(randomStrings, randomInt, randomCharacter)])
        func contentVariableInitialValueTesting(
            string: String,
            int: Int,
            character: Character
        ) async throws {
            let style = TextStyle(foreground: .red)
            let text1 = Text(string)
            let text2 = Text(repeating: character, count: int)
            let text3 = Text(style: style, repeating: character, count: int)
            let text4 = Text(style: style, content: string)

            #expect(text1.contents == [string])
            #expect(text2.contents == [String(repeating: character, count: int)])
            #expect(text3.contents == [String(repeating: character, count: int)])
            #expect(text4.contents == [string])
        }

        @Test("Is the color set by the forgroundColor function applied to the style variable?", arguments: allColors)
        func forgroundColorFuncTesting(
            color: Color
        ) async throws {
            // The innermost application wins; a repeated application collapses.
            let text = Text("").forgroundColor(color).forgroundColor(.primary)

            #expect(text.style == TextStyle(foreground: color))
        }

        @Test("Is the color set by the background function applied to the style variable?", arguments: allColors)
        func backgroundFuncTesting(
            color: Color
        ) async throws {
            let text = Text("").background(color).background(.primary)

            #expect(text.style == TextStyle(background: color))
        }

        @Test("Is the thickness set by the bold function applied to the style variable?")
        func boldFuncTesting() async throws {
            let text1 = Text("").bold()
            let text2 = Text("").bold(true)
            let text3 = Text("").bold(false)

            #expect(text1.style == TextStyle(weight: .bold))
            #expect(text2.style == TextStyle(weight: .bold))
            #expect(text3.style.isPlain)
        }

        @Test("Is the thickness set by the fontWeight function applied to the style variable?", arguments: Weight.allCases)
        func fontWeightFuncTesting(
            weight: Weight
        ) async throws {
            let text = Text("").fontWeight(weight)

            if weight == .default {
                #expect(text.style.isPlain)
            } else {
                #expect(text.style == TextStyle(weight: weight))
            }
        }

        @Test("Is the style set by the italic function applied to the style variable?")
        func italicFuncTesting() async throws {
            let text1 = Text("").italic()
            let text2 = Text("").italic(true)
            let text3 = Text("").italic(false)

            #expect(text1.style == TextStyle(isItalic: true))
            #expect(text2.style == TextStyle(isItalic: true))
            #expect(text3.style.isPlain)
        }

        @Test("Is the style set by the underline function applied to the style variable?")
        func underlineFuncTesting() async throws {
            let text1 = Text("").underline()
            let text2 = Text("").underline(true)
            let text3 = Text("").underline(false)

            #expect(text1.style == TextStyle(isUnderlined: true))
            #expect(text2.style == TextStyle(isUnderlined: true))
            #expect(text3.style.isPlain)
        }

        @Test("Is the style set by the blink function applied to the style variable?", arguments: BlinkStyle.allCases)
        func blinkFuncTesting(
            blink: BlinkStyle
        ) async throws {
            let text = Text("").blink(blink)

            if blink == .none {
                #expect(text.style.isPlain)
            } else {
                #expect(text.style == TextStyle(blink: blink))
            }
        }

        @Test("Is the style set by the hidden function applied to the style variable?")
        func hiddenFuncTesting() async throws {
            let text1 = Text("").hidden()
            let text2 = Text("").hidden(true)
            let text3 = Text("").hidden(false)

            #expect(text1.style == TextStyle(isHidden: true))
            #expect(text2.style == TextStyle(isHidden: true))
            #expect(text3.style.isPlain)
        }

        @Test("Is the style set by the strikethrough function applied to the style variable?")
        func strikethroughFuncTesting() async throws {
            let text1 = Text("").strikethrough()
            let text2 = Text("").strikethrough(true)
            let text3 = Text("").strikethrough(false)

            #expect(text1.style == TextStyle(isStrikethrough: true))
            #expect(text2.style == TextStyle(isStrikethrough: true))
            #expect(text3.style.isPlain)
        }

        @Test("Does the escape lowering follow the canonical attribute order?")
        func ansiPrefixCanonicalOrderTesting() async throws {
            let style = TextStyle(
                foreground: .red,
                background: .blue,
                weight: .bold,
                isItalic: true,
                isUnderlined: true,
                blink: .default,
                isStrikethrough: true
            )

            #expect(style.ansiPrefix == "\u{001B}[1m\u{001B}[3m\u{001B}[4m\u{001B}[5m\u{001B}[9m\u{001B}[31m\u{001B}[44m")
        }
    }
}

#endif
