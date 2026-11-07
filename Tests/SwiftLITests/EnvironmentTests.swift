//
//  EnvironmentTests.swift
//  SwiftLITests
//
//  Created by Keisuke Chinone on 2026/07/10.
//

#if swift(>=6.0)
import Testing
@_spi(RenderingInternals) @testable import SwiftLI
import Foundation

// MARK: - Probe views

/// Renders the `\.maxWidth` visible at its position in the tree.
private struct WidthProbe: View {
    @Environment(\.maxWidth) var maxWidth

    var body: some View {
        Text("W=\(maxWidth)")
    }
}

/// Renders the `\.colorScheme` visible at its position in the tree.
private struct SchemeProbe: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Text(colorScheme == .light ? "LIGHT" : "DARK")
    }
}

// MARK: - A user-defined environment value

private struct TestFlagKey: EnvironmentKey {
    static var defaultValue: String { "default" }
}

extension EnvironmentValues {
    fileprivate var testFlag: String {
        get { self[TestFlagKey.self] }
        set { self[TestFlagKey.self] = newValue }
    }
}

// The same kind of value declared with the `@Entry` macro.
extension EnvironmentValues {
    @Entry fileprivate var entryFlag: String = "entry-default"
    @Entry fileprivate var optionalEntry: Int?
}

private struct EntryProbe: View {
    @Environment(\.entryFlag) var flag
    @Environment(\.optionalEntry) var number

    var body: some View {
        Text("\(flag)/\(number.map(String.init) ?? "nil")")
    }
}

private struct FlagProbe: View {
    @Environment(\.testFlag) var flag

    var body: some View {
        Text(flag)
    }
}

// MARK: - Tests

@Suite("Environment Testing")
struct EnvironmentTests {
    private func plain(_ v: some View) -> String {
        TextMetrics.stripANSI(v.renderString())
    }

    @Test(".scrollIndicators hides the scrollbar for the axes it names")
    func scrollIndicatorsModifier() {
        // The vertical bar's track is painted with this background.
        let track = TextStyle(background: .eightBit(238)).sgrPrefix
        func tall() -> some View {
            ScrollView {
                ForEach(0..<20) { i in Text("row \(i)") }
            }
            .frame(width: 20, height: 5)
        }
        #expect(tall().renderString().contains(track))
        #expect(tall().scrollIndicators(.visible).renderString().contains(track))
        #expect(!tall().scrollIndicators(.hidden).renderString().contains(track))
        #expect(!tall().scrollIndicators(.never, axes: .vertical).renderString().contains(track))
        // Hiding only the horizontal axis leaves a vertical bar alone.
        #expect(tall().scrollIndicators(.hidden, axes: .horizontal).renderString().contains(track))
        // The setting flows down the environment from an enclosing container.
        #expect(!VStack { tall() }.scrollIndicators(.hidden).renderString().contains(track))
    }

    @Test("At the top level, maxWidth matches the terminal width")
    func topLevelMaxWidth() {
        #expect(plain(WidthProbe()) == "W=\(TerminalSize.current.columns)")
    }

    @Test("A fixed frame narrows maxWidth for its content")
    func frameNarrowsMaxWidth() {
        #expect(plain(WidthProbe().frame(width: 30, alignment: .topLeading)).contains("W=30"))
    }

    @Test("Width-consuming modifiers subtract their columns on the way down")
    func modifiersConsumeWidth() {
        // Outside-in: frame pins 30, padding consumes 2 × 2, border 2, so the
        // probe sees 30 − 4 − 2 = 24.
        let view = WidthProbe()
            .border(.primary)
            .padding(.horizontal, 2)
            .frame(width: 30, alignment: .topLeading)
        #expect(plain(view).contains("W=24"))
    }

    @Test("environment(_:_:) injects a value for the subtree")
    func injectsColorScheme() {
        #expect(plain(SchemeProbe().environment(\.colorScheme, .light)).contains("LIGHT"))
        #expect(plain(SchemeProbe().environment(\.colorScheme, .dark)).contains("DARK"))
    }

    @Test("A user-defined environment value reads its default and accepts injection")
    func customKey() {
        #expect(plain(FlagProbe()) == "default")
        #expect(plain(FlagProbe().environment(\.testFlag, "injected")) == "injected")
    }

    @Test("An @Entry value reads its default and accepts injection")
    func entryMacro() {
        #expect(plain(EntryProbe()) == "entry-default/nil")
        let view = EntryProbe()
            .environment(\.entryFlag, "injected")
            .environment(\.optionalEntry, 7)
        #expect(plain(view) == "injected/7")
    }

    @Test("The nearest environment injection wins")
    func nearestInjectionWins() {
        let view = FlagProbe()
            .environment(\.testFlag, "inner")
            .environment(\.testFlag, "outer")
        #expect(plain(view) == "inner")
    }

    @Test("transformEnvironment mutates the inherited value")
    func transformsValue() {
        let view = FlagProbe()
            .transformEnvironment(\.testFlag) { $0 += "-suffix" }
            .environment(\.testFlag, "base")
        #expect(plain(view) == "base-suffix")
    }
}

// MARK: - Dynamic colors

/// Applies a scheme-dynamic foreground inside `body`, so the color resolves
/// during the render pass — inside any enclosing environment scope.
private struct SecondaryProbe: View {
    var body: some View {
        Text("x").foregroundStyle(.secondary)
    }
}

/// Same, with a custom light/dark pair.
private struct DynamicPairProbe: View {
    var body: some View {
        Text("x").foregroundStyle(.dynamic(light: .red, dark: .yellow))
    }
}

@Suite("Dynamic Color Testing")
struct DynamicColorTests {
    @Test("A dynamic color resolves against the color scheme in scope")
    func dynamicColorFollowsScheme() {
        // .secondary = eightBit(240) on light, eightBit(245) on dark.
        let light = SecondaryProbe().environment(\.colorScheme, .light).renderString()
        #expect(light.contains("38;5;240"))

        let dark = SecondaryProbe().environment(\.colorScheme, .dark).renderString()
        #expect(dark.contains("38;5;245"))
    }

    @Test("dynamic(light:dark:) picks the matching side per scheme")
    func customDynamicColor() {
        #expect(DynamicPairProbe().environment(\.colorScheme, .light).renderString().contains("\u{001B}[31m"))
        #expect(DynamicPairProbe().environment(\.colorScheme, .dark).renderString().contains("\u{001B}[33m"))
    }

    @Test("The SwiftUI standard palette maps to 256-color entries")
    func standardPalette() {
        #expect(Color.gray.ansi == "8;5;245")
        #expect(Color.orange.ansi == "8;5;208")
        #expect(Color.pink.ansi == "8;5;205")
        #expect(Color.purple.ansi == "8;5;135")
        #expect(Color.brown.ansi == "8;5;130")
        #expect(Color.indigo.ansi == "8;5;63")
        #expect(Color.mint.ansi == "8;5;43")
        #expect(Color.teal.ansi == "8;5;38")
    }
}
#endif
