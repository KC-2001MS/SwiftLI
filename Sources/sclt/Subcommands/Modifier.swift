//
//  Modifier.swift
//  sclt
//
//  Created by Keisuke Chinone on 2026/07/10.
//

import Foundation
import ArgumentParser
import SwiftLI

/// A full-screen catalogue of every View-independent modifier: the interactive
/// ones (sheet, inspector, focused, onAppear, task) demonstrated live at the
/// top, the environment modifiers next, and the style / layout modifiers as a
/// scrollable row-per-modifier catalogue below.
struct ModifierCommand: FullScreenCommand {
    static let configuration = CommandConfiguration(
        commandName: "modifier",
        abstract: "Display of every View-independent modifier",
        discussion: """
        Every modifier that applies to any View:
        - presentation & lifecycle: sheet, inspector, focused, onAppear, task
        - environment: environment(_:_:), transformEnvironment(_:transform:)
        - style: forgroundColor, background, bold, fontWeight, italic,
          underline, strikethrough, blink, hidden
        - layout: padding (all three forms), frame(width:height:),
          frame(maxWidth:maxHeight:), lineLimit, border, shadow
        Every one of them is a thin wrapper over modifier(_:) — conform to
        ViewModifier to write your own. View-family styles (buttonStyle,
        listStyle, …) are shown in each view's own command, and the navigation
        bar modifiers in `sclt navigation`. Ctrl-C quits.
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    /// The column width reserved for each modifier's call site, so the samples
    /// line up.
    private var callWidth = 34

    private var paragraph: String { "SwiftLI wraps long text to the available width just like SwiftUI." }

    enum Field: Hashable { case sample }

    @State var showsSheet = false
    @State var showsInspector = false
    @State var sample = ""
    @State var appeared = false
    @State var ticks = 0
    @FocusState var focus: Field?

    // No run() — FullScreenCommand's default runs the session until Ctrl-C.

    /// One catalogue row: the call site in a fixed-width column, then the
    /// sample it produces.
    private func row(_ call: String, _ sample: some View) -> some View {
        HStack(spacing: 1) {
            Text(call).forgroundColor(.eight_bit(245)).frame(width: callWidth, alignment: .topLeading)
            sample
        }
    }

    var body: some Scene {
        NavigationStack {
            Text("Presentation & lifecycle modifiers:").forgroundColor(.cyan)
                .navigationTitle("Modifier")
                .navigationSubtitle("Tab: focus   Return/Space: activate   Ctrl-C: quit")

            // .sheet — a button presents a modal card; Close dismisses it.
            HStack(spacing: 1) {
                Text(".sheet(isPresented:content:)").forgroundColor(.eight_bit(245)).frame(width: callWidth, alignment: .topLeading)
                Button("Open sheet…") { showsSheet = true }
            }
                .sheet(isPresented: $showsSheet) {
                    Text("A modal sheet").bold()
                    Button("Close") { showsSheet = false }
                }

            // .inspector — a side panel toggled next to the content.
            HStack(spacing: 1) {
                Text(".inspector(isPresented:content:)").forgroundColor(.eight_bit(245)).frame(width: callWidth, alignment: .topLeading)
                Button("Toggle inspector") { showsInspector.toggle() }
            }
                .inspector(isPresented: $showsInspector) {
                    Text("Inspector").bold()
                    Text("Details of the selection.")
                }

            // .focused — ties a control to a bound focus value.
            row(".focused(_:equals:)", HStack(spacing: 1) {
                TextField("Type here", text: $sample)
                    .focused($focus, equals: .sample)
                Text(focus == .sample ? "focused" : "not focused").forgroundColor(focus == .sample ? .green : .eight_bit(240))
            })

            // .onAppear fires once when the view first renders; .task starts
            // async work tied to the view's lifetime.
            row(".onAppear(perform:)", Text("fired: \(appeared ? "yes" : "no")").forgroundColor(.green)
                .onAppear { appeared = true })
            row(".task(_:)", Text("async ticks: \(ticks)/5").forgroundColor(.green)
                .task {
                    for _ in 0..<5 {
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        ticks += 1
                    }
                })

            Text("Environment modifiers:").forgroundColor(.cyan)
                .padding(.top, 1)
            row(".environment(\\.colorScheme, _)", SchemeBadge().environment(\.colorScheme, .light))
            row(".transformEnvironment(\\.maxWidth)", WidthRule().transformEnvironment(\.maxWidth) { $0 = Swift.min($0, 24) })

            Text("Style & layout modifiers (Tab to the list, ↑/↓ scroll):").forgroundColor(.cyan)
                .padding(.top, 1)
            ScrollView {
                row(".forgroundColor(.red)", Text("Sample").forgroundColor(.red))
                row(".background(.yellow)", Text("Sample").background(.yellow).forgroundColor(.black))
                row(".bold()", Text("Sample").bold())
                row(".fontWeight(.thin)", Text("Sample").fontWeight(.thin))
                row(".italic()", Text("Sample").italic())
                row(".underline()", Text("Sample").underline())
                row(".strikethrough()", Text("Sample").strikethrough())
                row(".blink(.default)", Text("Sample").blink(.default))
                row(".hidden()", HStack(spacing: 0) {
                    Text("[").forgroundColor(.eight_bit(240))
                    Text("Sample").hidden()
                    Text("] (blanked, keeps its width)").forgroundColor(.eight_bit(240))
                })
                row(".padding()", Text("Sample").padding().background(.eight_bit(238)))
                row(".padding(.leading, 4)", Text("Sample").padding(.leading, 4).background(.eight_bit(238)))
                row(".padding(EdgeInsets(...))", Text("Sample").padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 6)).background(.eight_bit(238)))
                row(".frame(width: 14, height: 3, ...)", Text("Sample").frame(width: 14, height: 3, alignment: .center).background(.eight_bit(238)))
                row(".frame(maxWidth: .infinity, ...)", Text("Sample").frame(maxWidth: .infinity, alignment: .trailing).background(.eight_bit(238)))
                row(".frame(width: 22) + wrapping", Text(paragraph).frame(width: 22, alignment: .topLeading))
                row(".frame(width: 22, height: 2)", Text(paragraph).frame(width: 22, height: 2, alignment: .topLeading))
                row(".lineLimit(2)", Text(paragraph).frame(width: 22, alignment: .topLeading).lineLimit(2))
                row("Gauge().frame(width: 24)", Gauge(value: 0.62).frame(width: 24, alignment: .topLeading))
                row(".border(.rounded, color: .green)", Text("Sample").padding(.horizontal, 1).border(.rounded, color: .green))
                row(".border(fill:) + .shadow()", Text("Sample").padding(.horizontal, 1).border(.rounded, color: .white, fill: .eight_bit(24)).shadow())
            }
            .frame(height: 10)

            Divider()
                .padding(.top, 1)
            Text("All of the above wrap .modifier(_:) — conform to ViewModifier for your own.")
                .forgroundColor(.eight_bit(240))
            Text("View-family styles: each view's command   Navigation bar: sclt navigation")
                .forgroundColor(.eight_bit(240))
        }
    }
}

/// Shows the `\.colorScheme` its position in the tree resolves to.
private struct SchemeBadge: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Text("colorScheme here: \(colorScheme == .dark ? "dark" : "light")").bold()
    }
}

/// A rule exactly as wide as the columns its scope allows — the transform
/// above caps it at 24.
private struct WidthRule: View {
    @Environment(\.maxWidth) var maxWidth

    var body: some View {
        Text(repeating: "─", count: maxWidth).forgroundColor(.green)
    }
}
