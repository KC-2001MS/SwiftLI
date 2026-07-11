//
//  StyleEnvironment.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/10.
//

// Environment propagation for control styles.
//
// Each style protocol gets an environment slot so a style applied to a
// container flows down to every matching control in the subtree — the same
// behaviour as SwiftUI's style modifiers:
//
//     VStack {
//         Toggle("Wi-Fi", isOn: $wifi)
//         Toggle("Bluetooth", isOn: $bt)
//     }
//     .toggleStyle(CheckboxToggleStyle())   // applies to both toggles
//
// Resolution order inside each control (nearest wins): a style set directly
// on the control instance, then the innermost environment value, then the
// control's default style. Controls resolve during `makeNode()`, which always
// runs inside the render pass's environment scope.

// MARK: - Environment keys

private struct ButtonStyleKey: EnvironmentKey {
    static var defaultValue: AnyButtonStyle? { nil }
}

private struct LabelStyleKey: EnvironmentKey {
    static var defaultValue: AnyLabelStyle? { nil }
}

private struct ToggleStyleKey: EnvironmentKey {
    static var defaultValue: AnyToggleStyle? { nil }
}

private struct PickerStyleKey: EnvironmentKey {
    static var defaultValue: AnyPickerStyle? { nil }
}

private struct GaugeStyleKey: EnvironmentKey {
    static var defaultValue: AnyGaugeStyle? { nil }
}

private struct ProgressViewStyleKey: EnvironmentKey {
    static var defaultValue: AnyProgressViewStyle? { nil }
}

private struct MenuStyleKey: EnvironmentKey {
    static var defaultValue: AnyMenuStyle? { nil }
}

private struct GroupBoxStyleKey: EnvironmentKey {
    static var defaultValue: AnyGroupBoxStyle? { nil }
}

private struct ListStyleKey: EnvironmentKey {
    static var defaultValue: AnyListStyle? { nil }
}

private struct TableStyleKey: EnvironmentKey {
    static var defaultValue: AnyTableStyle? { nil }
}

private struct TextFieldStyleKey: EnvironmentKey {
    static var defaultValue: AnyTextFieldStyle? { nil }
}

private struct SliderStyleKey: EnvironmentKey {
    static var defaultValue: AnySliderStyle? { nil }
}

extension EnvironmentValues {
    var buttonStyle: AnyButtonStyle? {
        get { self[ButtonStyleKey.self] }
        set { self[ButtonStyleKey.self] = newValue }
    }

    var labelStyle: AnyLabelStyle? {
        get { self[LabelStyleKey.self] }
        set { self[LabelStyleKey.self] = newValue }
    }

    var toggleStyle: AnyToggleStyle? {
        get { self[ToggleStyleKey.self] }
        set { self[ToggleStyleKey.self] = newValue }
    }

    var pickerStyle: AnyPickerStyle? {
        get { self[PickerStyleKey.self] }
        set { self[PickerStyleKey.self] = newValue }
    }

    var gaugeStyle: AnyGaugeStyle? {
        get { self[GaugeStyleKey.self] }
        set { self[GaugeStyleKey.self] = newValue }
    }

    var progressViewStyle: AnyProgressViewStyle? {
        get { self[ProgressViewStyleKey.self] }
        set { self[ProgressViewStyleKey.self] = newValue }
    }

    var menuStyle: AnyMenuStyle? {
        get { self[MenuStyleKey.self] }
        set { self[MenuStyleKey.self] = newValue }
    }

    var groupBoxStyle: AnyGroupBoxStyle? {
        get { self[GroupBoxStyleKey.self] }
        set { self[GroupBoxStyleKey.self] = newValue }
    }

    var listStyle: AnyListStyle? {
        get { self[ListStyleKey.self] }
        set { self[ListStyleKey.self] = newValue }
    }

    var tableStyle: AnyTableStyle? {
        get { self[TableStyleKey.self] }
        set { self[TableStyleKey.self] = newValue }
    }

    var textFieldStyle: AnyTextFieldStyle? {
        get { self[TextFieldStyleKey.self] }
        set { self[TextFieldStyleKey.self] = newValue }
    }

    var sliderStyle: AnySliderStyle? {
        get { self[SliderStyleKey.self] }
        set { self[SliderStyleKey.self] = newValue }
    }
}

// MARK: - Subtree style modifiers

public extension View {
    /// Sets the ``ButtonStyle`` for every ``Button`` in this view's subtree.
    ///
    /// A style set directly on a button (``Button/buttonStyle(_:)``) overrides
    /// the environment value, and the innermost subtree style wins.
    func buttonStyle(_ style: some ButtonStyle) -> some View {
        environment(\.buttonStyle, AnyButtonStyle(style))
    }

    /// Sets the ``LabelStyle`` for every ``Label`` in this view's subtree.
    ///
    /// A style set directly on a label (``Label/labelStyle(_:)``) overrides
    /// the environment value, and the innermost subtree style wins.
    func labelStyle(_ style: some LabelStyle) -> some View {
        environment(\.labelStyle, AnyLabelStyle(style))
    }

    /// Sets the ``ToggleStyle`` for every ``Toggle`` in this view's subtree.
    ///
    /// A style set directly on a toggle (``Toggle/toggleStyle(_:)``) overrides
    /// the environment value, and the innermost subtree style wins.
    func toggleStyle(_ style: some ToggleStyle) -> some View {
        environment(\.toggleStyle, AnyToggleStyle(style))
    }

    /// Sets the ``PickerStyle`` for every ``Picker`` in this view's subtree.
    ///
    /// A style set directly on a picker (``Picker/pickerStyle(_:)``) overrides
    /// the environment value, and the innermost subtree style wins.
    func pickerStyle(_ style: some PickerStyle) -> some View {
        environment(\.pickerStyle, AnyPickerStyle(style))
    }

    /// Sets the ``GaugeStyle`` for every ``Gauge`` in this view's subtree.
    ///
    /// A style set directly on a gauge (``Gauge/gaugeStyle(_:)``) overrides
    /// the environment value, and the innermost subtree style wins.
    func gaugeStyle(_ style: some GaugeStyle) -> some View {
        environment(\.gaugeStyle, AnyGaugeStyle(style))
    }

    /// Sets the ``ProgressViewStyle`` for every ``ProgressView`` in this view's subtree.
    ///
    /// A style set directly on a progress view (``ProgressView/progressViewStyle(_:)``)
    /// overrides the environment value, and the innermost subtree style wins.
    func progressViewStyle(_ style: some ProgressViewStyle) -> some View {
        environment(\.progressViewStyle, AnyProgressViewStyle(style))
    }

    /// Sets the ``MenuStyle`` for every ``Menu`` in this view's subtree.
    ///
    /// A style set directly on a menu (``Menu/menuStyle(_:)``) overrides
    /// the environment value, and the innermost subtree style wins.
    func menuStyle(_ style: some MenuStyle) -> some View {
        environment(\.menuStyle, AnyMenuStyle(style))
    }

    /// Sets the ``GroupBoxStyle`` for every ``GroupBox`` in this view's subtree.
    ///
    /// A style set directly on a group box (``GroupBox/groupBoxStyle(_:)``)
    /// overrides the environment value, and the innermost subtree style wins.
    func groupBoxStyle(_ style: some GroupBoxStyle) -> some View {
        environment(\.groupBoxStyle, AnyGroupBoxStyle(style))
    }

    /// Sets the ``ListStyle`` for every ``List`` in this view's subtree.
    ///
    /// A style set directly on a list (``List/listStyle(_:)``) overrides
    /// the environment value, and the innermost subtree style wins.
    func listStyle(_ style: some ListStyle) -> some View {
        environment(\.listStyle, AnyListStyle(style))
    }

    /// Sets the ``TableStyle`` for every ``Table`` in this view's subtree.
    ///
    /// A style set directly on a table (``Table/tableStyle(_:)``) overrides
    /// the environment value, and the innermost subtree style wins.
    func tableStyle(_ style: some TableStyle) -> some View {
        environment(\.tableStyle, AnyTableStyle(style))
    }

    /// Sets the ``TextFieldStyle`` for every ``TextField`` in this view's subtree.
    ///
    /// A style set directly on a field (``TextField/textFieldStyle(_:)``)
    /// overrides the environment value, and the innermost subtree style wins.
    func textFieldStyle(_ style: some TextFieldStyle) -> some View {
        environment(\.textFieldStyle, AnyTextFieldStyle(style))
    }

    /// Sets the ``SliderStyle`` for every ``Slider`` in this view's subtree.
    ///
    /// A style set directly on a slider (``Slider/sliderStyle(_:)``) overrides
    /// the environment value, and the innermost subtree style wins.
    func sliderStyle(_ style: some SliderStyle) -> some View {
        environment(\.sliderStyle, AnySliderStyle(style))
    }
}
