//
//  StyleTests.swift
//  SwiftLITests
//
//  Created by Keisuke Chinone on 2026/07/10.
//

#if swift(>=6.0)
import Testing
@_spi(RenderingInternals) @testable import SwiftLI
import Foundation

// MARK: - Toggle style testing

@Suite("Toggle Style Testing")
struct ToggleStyleTests {
    private func plain(_ v: some View) -> String {
        TextMetrics.stripANSI(v.renderString())
    }
    private func config(_ isOn: Bool, focused: Bool = false, label: String = "OK") -> ToggleStyleConfiguration {
        ToggleStyleConfiguration(label: label.isEmpty ? nil : AnyView(Text(label)), isOn: isOn, isFocused: focused)
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
        PickerStyleConfiguration(label: AnyView(Text("Color")), options: ["Red", "Green", "Blue"], selectedIndex: selected, isFocused: false)
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
        let focused = PickerStyleConfiguration(label: AnyView(Text("Color")), options: ["Red", "Green", "Blue"], selectedIndex: 0, isFocused: true)
        let blurred = PickerStyleConfiguration(label: AnyView(Text("Color")), options: ["Red", "Green", "Blue"], selectedIndex: 0, isFocused: false)
        // Styling (colour/bold) differs, so the raw escape output must differ…
        #expect(ListPickerStyle().makeBody(configuration: focused).renderString()
                != ListPickerStyle().makeBody(configuration: blurred).renderString())
        // …and the focused header carries the ">" marker.
        #expect(plain(ListPickerStyle().makeBody(configuration: focused)).contains("> Color"))
    }
}

// MARK: - Environment style propagation

@Suite("Environment Style Propagation")
struct EnvironmentStylePropagationTests {
    private func plain(_ v: some View) -> String {
        TextMetrics.stripANSI(v.renderString())
    }

    @Test("A container labelStyle flows down to every label in the subtree")
    func labelStyleFlowsToSubtree() {
        let out = plain(
            VStack {
                Label(image: "★", title: "Favorite")
            }
            .labelStyle(.titleOnly)
        )
        #expect(out.contains("Favorite"))
        #expect(!out.contains("★"))
    }

    @Test("A style set directly on the control overrides the environment")
    func instanceStyleOverridesEnvironment() {
        let out = plain(
            VStack {
                Label(image: "★", title: "Favorite").labelStyle(.iconOnly)
            }
            .labelStyle(.titleOnly)
        )
        #expect(out.contains("★"))
        #expect(!out.contains("Favorite"))
    }

    @Test("The innermost subtree style wins over an outer one")
    func innermostEnvironmentStyleWins() {
        let out = plain(
            VStack {
                VStack {
                    Label(image: "★", title: "Favorite")
                }
                .labelStyle(.iconOnly)
            }
            .labelStyle(.titleOnly)
        )
        #expect(out.contains("★"))
        #expect(!out.contains("Favorite"))
    }

    @Test("Without any style the default rendering is unchanged")
    func defaultBehaviourUnchanged() {
        let bare = plain(Label(image: "★", title: "Favorite"))
        let wrapped = plain(VStack { Label(image: "★", title: "Favorite") })
        #expect(bare.contains("★"))
        #expect(bare.contains("Favorite"))
        #expect(bare == wrapped)
    }

    @Test("An environment style renders identically to the same instance style")
    func environmentMatchesInstanceApplication() {
        let viaEnvironment = plain(
            VStack { Gauge(value: 0.5, width: 10) }.gaugeStyle(BarGaugeStyle())
        )
        let viaInstance = plain(
            VStack { Gauge(value: 0.5, width: 10).gaugeStyle(BarGaugeStyle()) }
        )
        #expect(viaEnvironment == viaInstance)
    }
}

#endif
