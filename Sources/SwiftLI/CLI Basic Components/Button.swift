//
//  Button.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/10.
//

import Foundation

// MARK: - ButtonRole

/// A value that describes the purpose of a button, mirroring SwiftUI's
/// `ButtonRole`. Styles use the role to adjust their appearance — a
/// ``ButtonRole/destructive`` button renders its label in red.
public struct ButtonRole: Equatable, Sendable {
    private enum Kind: Equatable, Sendable {
        case destructive
        case cancel
    }

    private let kind: Kind

    /// A role indicating a destructive action (e.g. deleting data).
    public static let destructive = ButtonRole(kind: .destructive)

    /// A role indicating an action that cancels the current operation.
    public static let cancel = ButtonRole(kind: .cancel)
}

// MARK: - ButtonStyle

/// The values passed to ``ButtonStyle/makeBody(configuration:)`` when rendering.
public struct ButtonStyleConfiguration {
    /// The button's label view.
    public let label: AnyView
    /// The button's semantic role, or `nil` for a standard button.
    public let role: ButtonRole?
    /// Whether the button currently has keyboard focus.
    public let isFocused: Bool
}

/// A type that defines the appearance of a ``Button``.
///
/// Conform to `ButtonStyle` and apply it with ``Button/buttonStyle(_:)``.
/// Built-in styles: ``DefaultButtonStyle`` (bracketed, default),
/// ``BorderedButtonStyle``, and ``PlainButtonStyle``.
public protocol ButtonStyle: Sendable {
    associatedtype Body: View
    @ViewBuilder func makeBody(configuration: ButtonStyleConfiguration) -> Body
}

// MARK: - Built-in styles

/// A one-line bracketed button: `[ Label ]`. When focused, a `> ` marker
/// appears and the label turns bold cyan.
public struct DefaultButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        let destructive = configuration.role == .destructive
        let bracket: Color = configuration.isFocused ? .cyan : .eight_bit(240)
        let labelColor: Color = destructive ? .red : (configuration.isFocused ? .cyan : .primary)
        HStack(spacing: 0) {
            if configuration.isFocused { Text(content: "> ").forgroundColor(.cyan) }
            Text(content: "[ ").forgroundColor(bracket)
            configuration.label
                .bold(configuration.isFocused)
                .forgroundColor(labelColor)
            Text(content: " ]").forgroundColor(bracket)
        }
    }
}

/// A button wrapped in a rounded border. The border (and label) light up cyan
/// while the button is focused, so it clearly reads as the active control.
public struct BorderedButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        let destructive = configuration.role == .destructive
        configuration.label
            .bold(configuration.isFocused)
            .forgroundColor(destructive ? .red : .primary)
            .padding(.horizontal, 1)
            .border(.rounded, color: configuration.isFocused ? .cyan : .eight_bit(240))
    }
}

/// A chromeless button: just the label, bold cyan while focused and dimmed
/// otherwise.
public struct PlainButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        let destructive = configuration.role == .destructive
        configuration.label
            .bold(configuration.isFocused)
            .forgroundColor(destructive ? .red : (configuration.isFocused ? .cyan : .eight_bit(245)))
    }
}

public extension ButtonStyle where Self == DefaultButtonStyle {
    /// The default bracketed button style: `[ Label ]`.
    static var automatic: Self { .init() }
}

public extension ButtonStyle where Self == BorderedButtonStyle {
    /// A button style that wraps the label in a rounded border.
    static var bordered: Self { .init() }
}

public extension ButtonStyle where Self == PlainButtonStyle {
    /// A button style that shows only the label.
    static var plain: Self { .init() }
}

// MARK: - AnyButtonStyle (type erasure)

/// A type-erased ``ButtonStyle`` whose erased result is an ``AnyView`` — a
/// plain composition of views, matching how ``AnyToggleStyle`` works.
struct AnyButtonStyle: ButtonStyle, @unchecked Sendable {
    private let _makeBody: (ButtonStyleConfiguration) -> any View

    init<S: ButtonStyle>(_ style: S) {
        _makeBody = { style.makeBody(configuration: $0) }
    }

    func makeBody(configuration: ButtonStyleConfiguration) -> AnyView {
        AnyView(erasing: _makeBody(configuration))
    }
}

// MARK: - Button

/// A focusable control that performs an action when activated.
///
/// `Button` mirrors SwiftUI's `Button`, adapted to the terminal. While a
/// reactive runtime is active and the button is focused, <kbd>Return</kbd> or
/// <kbd>Space</kbd> fires its action, and <kbd>Tab</kbd> / <kbd>Shift-Tab</kbd>
/// move focus. Its appearance is chosen by a ``ButtonStyle`` —
/// ``DefaultButtonStyle`` (`[ Label ]`) by default.
///
/// ```swift
/// @State var count = 0
///
/// var body: some View {
///     Button("Increment") { count += 1 }
///     Text("count: \(count)")
/// }
/// ```
///
/// A custom label composes like any other view:
///
/// ```swift
/// Button(action: save) {
///     Label("Save", unicodeImage: 0x1F4BE)
/// }
/// .buttonStyle(.bordered)
/// ```
public struct Button: View {
    let header: String
    let id: String
    let label: AnyView
    let role: ButtonRole?
    let action: () -> Void
    let style: AnyButtonStyle

    /// Creates a button with a localized title.
    /// - Parameters:
    ///   - title: The text shown as the button's label; also the default identity.
    ///   - role: The button's semantic role (e.g. ``ButtonRole/destructive``),
    ///     or `nil` for a standard button.
    ///   - id: An explicit identity; defaults to the title.
    ///   - action: Called when the button is activated (<kbd>Return</kbd> or
    ///     <kbd>Space</kbd> while focused).
    public init(
        _ title: LocalizedStringKey,
        role: ButtonRole? = nil,
        id: String? = nil,
        action: @escaping () -> Void
    ) {
        let resolved = String(localized: title.localizationValue)
        self.header = ""
        self.id = id ?? (resolved.isEmpty ? "Button" : resolved)
        self.label = AnyView(Text(content: resolved))
        self.role = role
        self.action = action
        self.style = AnyButtonStyle(DefaultButtonStyle())
    }

    /// Creates a button with a custom label view.
    /// - Parameters:
    ///   - role: The button's semantic role, or `nil` for a standard button.
    ///   - id: An explicit identity; defaults to `"Button"` — give each button
    ///     a distinct `id` when a screen shows more than one custom-labelled
    ///     button.
    ///   - action: Called when the button is activated.
    ///   - label: A ``ViewBuilder`` producing the button's label.
    public init<Label: View>(
        role: ButtonRole? = nil,
        id: String = "Button",
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.header = ""
        self.id = id
        self.label = AnyView(label())
        self.role = role
        self.action = action
        self.style = AnyButtonStyle(DefaultButtonStyle())
    }

    init(header: String, id: String, label: AnyView, role: ButtonRole?, action: @escaping () -> Void, style: AnyButtonStyle) {
        self.header = header
        self.id = id
        self.label = label
        self.role = role
        self.action = action
        self.style = style
    }

    public var body: some View {
        EmptyView()
    }

    @_spi(RenderingInternals)
    public func addHeader(_ newHeader: String) -> Self {
        Button(header: newHeader + header, id: id, label: label, role: role, action: action, style: style)
    }

    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        FocusCoordinator.shared.registerButton(id: id, action: action)
        KeyInputRouter.shared.ensureStarted()

        let configuration = ButtonStyleConfiguration(
            label: label,
            role: role,
            isFocused: FocusCoordinator.shared.isFocused(id)
        )
        let node = style.makeBody(configuration: configuration).makeNode()
        return header.isEmpty ? node : node.applyingHeader(header)
    }

    /// Sets the style used to render this button.
    /// - Parameter newStyle: A value conforming to ``ButtonStyle``.
    public func buttonStyle(_ newStyle: some ButtonStyle) -> Self {
        Button(header: header, id: id, label: label, role: role, action: action, style: AnyButtonStyle(newStyle))
    }
}
