//
//  TextField.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/07.
//

import Foundation

/// An editable single-line text field bound to a `Binding<String>`.
///
/// `TextField` mirrors SwiftUI's `TextField`. While a reactive runtime is
/// active (a ``CLIApp`` or a ``ViewableCommand`` that called
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
    let header: String
    /// Stable identity used to track focus and cursor position across renders.
    let id: String
    let placeholder: String
    let text: Binding<String>
    let onSubmit: (() -> Void)?

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
        let resolved = String(localized: placeholder.localizationValue)
        self.header = ""
        self.id = id ?? resolved
        self.placeholder = resolved
        self.text = text
        self.onSubmit = onSubmit
    }

    init(header: String, id: String, placeholder: String, text: Binding<String>, onSubmit: (() -> Void)?) {
        self.header = header
        self.id = id
        self.placeholder = placeholder
        self.text = text
        self.onSubmit = onSubmit
    }

    public var body: some View { Group(contents: []) }

    @_spi(RenderingInternals)
    public func addHeader(_ newHeader: String) -> Self {
        TextField(header: newHeader + header, id: id, placeholder: placeholder, text: text, onSubmit: onSubmit)
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
        let value = text.wrappedValue
        let marker = focused ? "> " : "  "

        let composed: Group
        if value.isEmpty && !focused {
            composed = Group(contents: [
                Text(content: marker),
                Text(content: placeholder).forgroundColor(.eight_bit(240))
            ])
        } else if focused {
            let chars = Array(value)
            let c = Swift.min(Swift.max(FocusCoordinator.shared.cursor(for: id), 0), chars.count)
            let before = String(chars[0..<c])
            let cursorChar = c < chars.count ? String(chars[c]) : " "
            let after = c < chars.count ? String(chars[(c + 1)...]) : ""

            var children: [any View] = [Text(content: marker).forgroundColor(.cyan)]
            if !before.isEmpty { children.append(Text(content: before)) }
            // Block cursor: reverse the foreground/background of the cell.
            children.append(Text(content: cursorChar).background(.white).forgroundColor(.black))
            if !after.isEmpty { children.append(Text(content: after)) }
            composed = Group(contents: children)
        } else {
            composed = Group(contents: [Text(content: marker), Text(content: value)])
        }

        // Lay the pieces out on a single row.
        let row = HStack(spacing: 0) { composed }
        let node = row.makeNode()
        return header.isEmpty ? node : node.applyingHeader(header)
    }
}
