//
//  Toggle.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/07.
//

import Foundation

// MARK: - ToggleStyle

/// The values passed to ``ToggleStyle/makeBody(configuration:)`` when rendering.
public struct ToggleStyleConfiguration {
    /// The toggle's label view, or `nil` when the toggle has no label.
    public let label: AnyView?
    /// Whether the toggle is currently on.
    public let isOn: Bool
    /// Whether the toggle currently has keyboard focus.
    public let isFocused: Bool
}

/// A type that defines the appearance of a ``Toggle``.
///
/// Conform to `ToggleStyle` to draw a boolean control however you like, then
/// apply it with ``Toggle/toggleStyle(_:)``. Built-in styles:
/// ``YesNoToggleStyle`` (the default), ``CheckboxToggleStyle``, and
/// ``SwitchToggleStyle``.
public protocol ToggleStyle: Sendable {
    associatedtype Body: View
    /// Produces the view representing the toggle for the given configuration.
    /// - Parameter configuration: The toggle's current state and label.
    /// - Returns: A view that renders the toggle.
    @ViewBuilder func makeBody(configuration: ToggleStyleConfiguration) -> Body
}

// MARK: - Built-in styles

/// A `Yes` / `No` selector — the classic confirmation prompt. The chosen side
/// is bracketed and coloured; the focused control brightens both options.
public struct YesNoToggleStyle: ToggleStyle {
    /// Creates a `YesNoToggleStyle`.
    public init() {}

    /// Produces a `Yes` / `No` selector view for the given configuration.
    /// - Parameter configuration: The toggle's current state and label.
    /// - Returns: A view displaying the `Yes` and `No` options.
    public func makeBody(configuration: ToggleStyleConfiguration) -> some View {
        let on = configuration.isOn
        let focused = configuration.isFocused
        let yesColor: Color = on ? .green : .eight_bit(240)
        let noColor: Color = !on ? .red : .eight_bit(240)

        return HStack(spacing: 0) {
            if focused { Text(content: "> ").forgroundColor(.cyan) }
            if let label = configuration.label {
                label
                Text(content: "  ")
            }
            Text(content: on ? "[Yes]" : " Yes ").forgroundColor(yesColor).bold(on)
            Text(content: " ")
            Text(content: !on ? "[No]" : " No ").forgroundColor(noColor).bold(!on)
        }
    }
}

/// A `[x]` / `[ ]` checkbox followed by the label.
public struct CheckboxToggleStyle: ToggleStyle {
    /// Creates a `CheckboxToggleStyle`.
    public init() {}

    /// Produces a checkbox view for the given configuration.
    /// - Parameter configuration: The toggle's current state and label.
    /// - Returns: A view displaying a `[x]` or `[ ]` checkbox with the label.
    public func makeBody(configuration: ToggleStyleConfiguration) -> some View {
        let box = configuration.isOn ? "[x]" : "[ ]"
        return HStack(spacing: 1) {
            Text(content: box).forgroundColor(configuration.isFocused ? .cyan : .primary)
            if let label = configuration.label { label }
        }
    }
}

/// A switch with a sliding knob **and** an explicit, colour-coded state word so
/// the value is unambiguous: `[──●] ON` in green when on, `[●──] OFF` in grey
/// when off. The label precedes it, and a focused switch shows a `>` marker.
public struct SwitchToggleStyle: ToggleStyle {
    /// Creates a `SwitchToggleStyle`.
    public init() {}

    /// Produces a sliding-knob switch view for the given configuration.
    /// - Parameter configuration: The toggle's current state and label.
    /// - Returns: A view displaying a track, knob, and colour-coded state word.
    public func makeBody(configuration: ToggleStyleConfiguration) -> some View {
        let on = configuration.isOn
        // The knob sits on the side that is active, and the state word repeats
        // the state in colour — position alone is easy to misread.
        let track = on ? "[──●]" : "[●──]"
        let word = on ? "ON" : "OFF"
        let color: Color = on ? .green : .eight_bit(244)

        return HStack(spacing: 1) {
            if configuration.isFocused { Text(content: ">").forgroundColor(.cyan) }
            if let label = configuration.label { label }
            Text(content: track).forgroundColor(color)
            Text(content: word).forgroundColor(color).bold()
        }
    }
}

/// A typed confirmation prompt — `label [y/n]: y` — like the classic
/// `Continue? [y/N]` shell prompt. You answer by typing `y` or `n`; the current
/// answer is echoed after the colon (with a block cursor while focused) and
/// <kbd>Return</kbd> confirms.
public struct PromptToggleStyle: ToggleStyle {
    /// Creates a `PromptToggleStyle`.
    public init() {}

    /// Produces a typed `[y/n]` prompt view for the given configuration.
    /// - Parameter configuration: The toggle's current state and label.
    /// - Returns: A view displaying the label, `[y/n]:` hint, and the current answer.
    public func makeBody(configuration: ToggleStyleConfiguration) -> some View {
        let answer = configuration.isOn ? "y" : "n"
        return HStack(spacing: 0) {
            if let label = configuration.label {
                label
                Text(content: " ")
            }
            Text(content: "[y/n]: ").forgroundColor(.eight_bit(240))
            if configuration.isFocused {
                Text(content: answer).background(.white).forgroundColor(.black)
            } else {
                Text(content: answer).forgroundColor(configuration.isOn ? .green : .red)
            }
        }
    }
}

// MARK: - AnyToggleStyle (type erasure)

/// A type-erased ``ToggleStyle`` whose erased result is an ``AnyView`` — a
/// plain composition of views, matching how ``AnyProgressViewStyle`` works.
struct AnyToggleStyle: ToggleStyle, @unchecked Sendable {
    private let _makeBody: (ToggleStyleConfiguration) -> any View

    init<S: ToggleStyle>(_ style: S) {
        _makeBody = { style.makeBody(configuration: $0) }
    }

    func makeBody(configuration: ToggleStyleConfiguration) -> AnyView {
        AnyView(erasing: _makeBody(configuration))
    }
}

// MARK: - Toggle

/// A focusable boolean control bound to a `Binding<Bool>`.
///
/// `Toggle` mirrors SwiftUI's `Toggle`, adapted to the terminal. While a
/// reactive runtime is active and the toggle is focused, <kbd>Space</kbd> flips
/// it, the arrows pick a side (Left = on, Right = off), `y`/`n` set it, and
/// <kbd>Tab</kbd> / <kbd>Shift-Tab</kbd> move focus. Its appearance is chosen by
/// a ``ToggleStyle`` — ``YesNoToggleStyle`` by default.
///
/// ```swift
/// @State var confirmed = true
///
/// var body: some View {
///     Toggle("Proceed?", isOn: $confirmed)
///         .toggleStyle(YesNoToggleStyle())
/// }
/// ```
public struct Toggle: View {
    let textStyle: TextStyle
    let id: String
    let label: AnyView?
    let isOn: Binding<Bool>
    /// The explicitly applied style, or `nil` to resolve from the environment.
    let style: AnyToggleStyle?

    /// Creates a toggle with a text label and a boolean binding.
    ///
    /// A toggle is a pure value editor — it has no submit hook. Pair it with a
    /// ``Button`` when a flow needs an explicit confirmation step.
    ///
    /// - Parameters:
    ///   - label: The text shown beside the control; also the default identity.
    ///   - isOn: The bound boolean.
    ///   - id: An explicit identity; defaults to the label.
    public init(
        _ label: LocalizedStringKey = "",
        isOn: Binding<Bool>,
        id: String? = nil
    ) {
        let resolved = String(localized: label.localizationValue)
        self.textStyle = .plain
        self.id = id ?? (resolved.isEmpty ? "Toggle" : resolved)
        self.label = resolved.isEmpty ? nil : AnyView(Text(content: resolved))
        self.isOn = isOn
        self.style = nil
    }

    /// Creates a toggle with a custom label view.
    /// - Parameters:
    ///   - isOn: The bound boolean.
    ///   - id: An explicit identity; defaults to `"Toggle"` — give each toggle
    ///     a distinct `id` when a screen shows more than one.
    ///   - label: A ``ViewBuilder`` producing the toggle's label.
    public init<Label: View>(
        isOn: Binding<Bool>,
        id: String = "Toggle",
        @ViewBuilder label: () -> Label
    ) {
        self.textStyle = .plain
        self.id = id
        self.label = AnyView(label())
        self.isOn = isOn
        self.style = nil
    }

    init(textStyle: TextStyle, id: String, label: AnyView?, isOn: Binding<Bool>, style: AnyToggleStyle?) {
        self.textStyle = textStyle
        self.id = id
        self.label = label
        self.isOn = isOn
        self.style = style
    }

    /// The content and behavior of the toggle; always an `EmptyView` because
    /// rendering is driven by ``makeNode()`` rather than the SwiftUI body pipeline.
    public var body: some View {
        EmptyView()
    }

    @_spi(RenderingInternals)
    public func applyingStyle(_ style: TextStyle) -> Self {
        Toggle(textStyle: textStyle.inheriting(style), id: id, label: label, isOn: isOn, style: self.style)
    }

    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        FocusCoordinator.shared.registerToggle(id: id, isOn: isOn)
        KeyInputRouter.shared.ensureStarted()

        let configuration = ToggleStyleConfiguration(
            label: label,
            isOn: isOn.wrappedValue,
            isFocused: FocusCoordinator.shared.isFocused(id)
        )
        // Nearest wins: instance style, then subtree environment, then default.
        let resolvedStyle = style ?? EnvironmentStack.current.toggleStyle ?? AnyToggleStyle(YesNoToggleStyle())
        let node = resolvedStyle.makeBody(configuration: configuration).makeNode()
        return (textStyle.isPlain ? node : node.applyingStyle(textStyle)).asControl(id: id)
    }

    /// Sets the style used to render this toggle.
    /// - Parameter newStyle: A value conforming to ``ToggleStyle``.
    public func toggleStyle(_ newStyle: some ToggleStyle) -> Self {
        Toggle(textStyle: textStyle, id: id, label: label, isOn: isOn, style: AnyToggleStyle(newStyle))
    }
}
