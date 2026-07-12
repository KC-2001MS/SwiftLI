//
//  TextField.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/07.
//

import Foundation

// MARK: - TextFieldStyle protocol

/// The values passed to ``TextFieldStyle/makeBody(configuration:)`` when rendering.
public struct TextFieldStyleConfiguration {
    /// The prompt shown when the field is empty and unfocused.
    public let placeholder: String
    /// The field's current text.
    public let text: String
    /// Whether the field currently has keyboard focus.
    public let isFocused: Bool
    /// The edit position within ``text`` (clamped to its length). Meaningful
    /// while the field is focused.
    public let cursorIndex: Int
    /// The owning field's identity, so built-in styles can mark the text run
    /// as a pointer sub-region (a click on it moves the cursor there).
    var _controlID: String? = nil
}

/// A type that defines the appearance of a ``TextField``.
///
/// Conform to `TextFieldStyle` and apply it with ``TextField/textFieldStyle(_:)``
/// (or ``View/textFieldStyle(_:)`` for a whole subtree). The default style is
/// ``DefaultTextFieldStyle``.
public protocol TextFieldStyle: Sendable {
    /// The type of view produced by this style.
    associatedtype Body: View

    /// Returns a view that represents the text field.
    ///
    /// Keep the result on a single line — the field registers itself as a
    /// one-line control in the focus ring.
    ///
    /// - Parameter configuration: The field's text, placeholder, and focus state.
    @ViewBuilder
    func makeBody(configuration: TextFieldStyleConfiguration) -> Body
}

/// The default text field style — a `>` marker while focused, a block cursor
/// at the edit position, and the placeholder dimmed when the field is empty
/// and unfocused. Equivalent to ``TextFieldStyle/automatic``.
public struct DefaultTextFieldStyle: TextFieldStyle {
    /// Creates a default text field style.
    public init() {}

    /// Returns a view that renders the text field with a focus marker and block cursor.
    ///
    /// - Parameter configuration: The field's placeholder, text, focus state, and cursor position.
    public func makeBody(configuration: TextFieldStyleConfiguration) -> some View {
        let value = configuration.text
        let focused = configuration.isFocused
        let marker = focused ? "> " : "  "

        // The editable run is a pointer sub-region: a click on it moves the
        // cursor to the clicked column.
        func textRegion(_ content: any View) -> HitRegion {
            HitRegion(controlID: configuration._controlID, role: MouseTargetRegistry.textRole, content: content)
        }

        let composed: Group
        if value.isEmpty && !focused {
            composed = Group(contents: [
                Text(content: marker),
                textRegion(Text(content: configuration.placeholder).forgroundColor(.eight_bit(240)))
            ])
        } else if focused {
            let chars = Array(value)
            let c = Swift.min(Swift.max(configuration.cursorIndex, 0), chars.count)
            let before = String(chars[0..<c])
            let cursorChar = c < chars.count ? String(chars[c]) : " "
            let after = c < chars.count ? String(chars[(c + 1)...]) : ""

            var cells: [any View] = []
            if !before.isEmpty { cells.append(Text(content: before)) }
            // Block cursor: reverse the foreground/background of the cell.
            cells.append(Text(content: cursorChar).background(.white).forgroundColor(.black))
            if !after.isEmpty { cells.append(Text(content: after)) }
            composed = Group(contents: [
                Text(content: marker).forgroundColor(.cyan),
                textRegion(HStack(spacing: 0) { Group(contents: cells) })
            ])
        } else {
            composed = Group(contents: [Text(content: marker), textRegion(Text(content: value))])
        }

        // Lay the pieces out on a single row.
        return HStack(spacing: 0) { composed }
    }
}

public extension TextFieldStyle where Self == DefaultTextFieldStyle {
    /// The default text field style: a focus marker and a block cursor.
    static var automatic: Self { .init() }
}

// MARK: - AnyTextFieldStyle (type erasure)

/// A type-erased ``TextFieldStyle`` whose erased result is an ``AnyView`` — a
/// plain composition of views, matching how ``AnyToggleStyle`` works.
struct AnyTextFieldStyle: TextFieldStyle, @unchecked Sendable {
    private let _makeBody: (TextFieldStyleConfiguration) -> any View

    init<S: TextFieldStyle>(_ style: S) {
        _makeBody = { style.makeBody(configuration: $0) }
    }

    func makeBody(configuration: TextFieldStyleConfiguration) -> AnyView {
        AnyView(erasing: _makeBody(configuration))
    }
}

// MARK: - TextField

/// An editable single-line text field bound to a `Binding<String>`.
///
/// `TextField` mirrors SwiftUI's `TextField`. While a reactive runtime is
/// active (a ``CLIApp`` or a ``InlineCommand``/``FullScreenCommand`` that called
/// `startBodyRendering()`), the field registers itself with the runtime's
/// keyboard handling: the focused field receives keystrokes, editing its bound
/// string character-by-character, while <kbd>Tab</kbd> / <kbd>Shift-Tab</kbd>
/// move focus between fields and <kbd>Enter</kbd> invokes `onSubmit`.
///
/// ```swift
/// @State var name = ""
///
/// var body: some View {
///     HStack(spacing: 1) {
///         Text("Name:")
///         TextField("Enter your name", text: $name)
///     }
/// }
/// ```
///
/// The focused field shows a block cursor at the edit position; an empty,
/// unfocused field shows its placeholder dimmed.
///
/// > Note: Field identity is keyed by ``id``, which defaults to the placeholder
/// > text. Give each field a distinct placeholder, or pass an explicit `id`,
/// > when several share the same placeholder.
public struct TextField: View {
    let textStyle: TextStyle
    /// Stable identity used to track focus and cursor position across renders.
    let id: String
    let placeholder: String
    let text: Binding<String>
    let onSubmit: (() -> Void)?
    /// The explicitly applied style, or `nil` to resolve from the environment.
    let style: AnyTextFieldStyle?

    /// Creates a text field with a placeholder and a text binding.
    /// - Parameters:
    ///   - placeholder: Prompt shown when the field is empty and unfocused. Also
    ///     used as the field's identity unless `id` is given.
    ///   - text: The bound string to edit.
    ///   - id: An explicit identity; defaults to the placeholder text.
    ///   - onSubmit: Called when <kbd>Enter</kbd> is pressed while focused.
    public init(
        _ placeholder: LocalizedStringKey = "",
        text: Binding<String>,
        id: String? = nil,
        onSubmit: (() -> Void)? = nil
    ) {
        let resolved = placeholder.resolve()
        self.textStyle = .plain
        self.id = id ?? resolved
        self.placeholder = resolved
        self.text = text
        self.onSubmit = onSubmit
        self.style = nil
    }

    init(textStyle: TextStyle, id: String, placeholder: String, text: Binding<String>, onSubmit: (() -> Void)?, style: AnyTextFieldStyle? = nil) {
        self.textStyle = textStyle
        self.id = id
        self.placeholder = placeholder
        self.text = text
        self.onSubmit = onSubmit
        self.style = style
    }

    /// The view content of the text field; rendering is handled by ``makeNode()``.
    public var body: some View {
        EmptyView()
    }

    @_spi(RenderingInternals)
    public func applyingStyle(_ style: TextStyle) -> Self {
        TextField(textStyle: textStyle.inheriting(style), id: id, placeholder: placeholder, text: text, onSubmit: onSubmit, style: self.style)
    }

    /// Registers the field for keyboard handling and lowers its current
    /// appearance (placeholder, text, and — when focused — a block cursor).
    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        // Register on every layout pass so the coordinator always has the latest
        // binding, and start keyboard input the first time any field appears.
        FocusCoordinator.shared.register(id: id, binding: text, onSubmit: onSubmit, keymap: SingleLineKeymap())
        KeyInputRouter.shared.ensureStarted()

        let focused = FocusCoordinator.shared.isFocused(id)

        // Nearest wins: instance style, then subtree environment, then default.
        let resolvedStyle = style ?? EnvironmentStack.current.textFieldStyle ?? AnyTextFieldStyle(DefaultTextFieldStyle())
        var configuration = TextFieldStyleConfiguration(
            placeholder: placeholder,
            text: text.wrappedValue,
            isFocused: focused,
            cursorIndex: FocusCoordinator.shared.cursor(for: id)
        )
        configuration._controlID = id
        let node = resolvedStyle.makeBody(configuration: configuration).makeNode()
        return (textStyle.isPlain ? node : node.applyingStyle(textStyle)).asControl(id: id)
    }

    /// Sets the style used to compose this text field.
    ///
    /// - Parameter newStyle: A value conforming to ``TextFieldStyle``.
    public func textFieldStyle(_ newStyle: some TextFieldStyle) -> Self {
        TextField(textStyle: textStyle, id: id, placeholder: placeholder, text: text, onSubmit: onSubmit, style: AnyTextFieldStyle(newStyle))
    }
}
