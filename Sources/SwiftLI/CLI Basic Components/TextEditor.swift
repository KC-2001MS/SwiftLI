//
//  TextEditor.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/07.
//

import Foundation

/// A multi-line editable text area bound to a `Binding<String>`.
///
/// `TextEditor` is the multi-line counterpart to ``TextField``. While a reactive
/// runtime is active it takes keystrokes when focused, and — unlike a text
/// field — <kbd>Return</kbd> inserts a newline while the up/down arrows move
/// between lines.
///
/// ## Leaving the editor
///
/// Following Textual's `TextArea`, the default ``TabBehavior/focus`` makes
/// <kbd>Tab</kbd> / <kbd>Shift-Tab</kbd> move focus between controls — so
/// leaving a control is uniform everywhere, and a form can freely mix
/// `TextField`s and a `TextEditor`. For a code editor, pass
/// `tabBehavior: .indent` (Textual's `TextArea.code_editor`): <kbd>Tab</kbd>
/// then inserts an indent and you leave the editor with <kbd>Esc</kbd>.
///
/// ```swift
/// @State var notes = ""
///
/// var body: some View {
///     TextEditor(text: $notes)                       // Tab leaves
///     TextEditor(text: $code, tabBehavior: .indent)  // Tab indents, Esc leaves
/// }
/// ```
///
/// Each line is drawn with a left gutter; the focused line shows a block cursor.
/// An empty, unfocused editor shows its placeholder dimmed.
///
/// > Note: Identity is keyed by ``id`` (defaults to the placeholder). Give a
/// > distinct `id` when several editors share a placeholder.
public struct TextEditor: View {
    /// How the <kbd>Tab</kbd> key behaves inside a ``TextEditor``.
    public enum TabBehavior: Sendable {
        /// Tab / Shift-Tab move focus to the next / previous control (default).
        /// Matches Textual's plain `TextArea`; leaving is uniform across the form.
        case focus
        /// Tab inserts an indent and Shift-Tab dedents; leave the editor with
        /// Escape. Matches Textual's `TextArea.code_editor`.
        case indent
    }

    let header: String
    let id: String
    let placeholder: String
    let text: Binding<String>
    let tabBehavior: TabBehavior
    let height: Int?

    /// Creates a multi-line text editor.
    /// - Parameters:
    ///   - placeholder: Prompt shown when empty and unfocused; also the default identity.
    ///   - text: The bound string to edit (may contain newlines).
    ///   - id: An explicit identity; defaults to the placeholder text.
    ///   - tabBehavior: Whether Tab moves focus (default) or indents (code editor).
    ///   - height: A fixed visible-row count. When the text has more lines than
    ///     this, the editor scrolls to keep the cursor line in view (drawing a
    ///     scrollbar). `nil` grows to fit all lines.
    public init(_ placeholder: LocalizedStringKey = "", text: Binding<String>, id: String? = nil, tabBehavior: TabBehavior = .focus, height: Int? = nil) {
        let resolved = String(localized: placeholder.localizationValue)
        self.header = ""
        self.id = id ?? (resolved.isEmpty ? "TextEditor" : resolved)
        self.placeholder = resolved
        self.text = text
        self.tabBehavior = tabBehavior
        self.height = height
    }

    init(header: String, id: String, placeholder: String, text: Binding<String>, tabBehavior: TabBehavior, height: Int?) {
        self.header = header
        self.id = id
        self.placeholder = placeholder
        self.text = text
        self.tabBehavior = tabBehavior
        self.height = height
    }

    public var body: some View { Group(contents: []) }

    @_spi(RenderingInternals)
    public func addHeader(_ newHeader: String) -> Self {
        TextEditor(header: newHeader + header, id: id, placeholder: placeholder, text: text, tabBehavior: tabBehavior, height: height)
    }

    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        let keymap = MultiLineKeymap(indentsWithTab: tabBehavior == .indent)
        FocusCoordinator.shared.register(id: id, binding: text, onSubmit: nil, keymap: keymap)
        KeyInputRouter.shared.ensureStarted()

        let focused = FocusCoordinator.shared.isFocused(id)
        let value = text.wrappedValue

        // Empty & unfocused → a single placeholder row.
        if value.isEmpty && !focused {
            let row = HStack(spacing: 0) {
                Text(content: "│ ").forgroundColor(.eight_bit(240))
                Text(content: placeholder).forgroundColor(.eight_bit(240))
            }
            let node = row.makeNode()
            return header.isEmpty ? node : node.applyingHeader(header)
        }

        // Locate the cursor's line and column from its flat character offset.
        let chars = Array(value)
        let c = Swift.min(Swift.max(FocusCoordinator.shared.cursor(for: id), 0), chars.count)
        var cursorLine = 0
        var cursorColumn = 0
        for i in 0..<c {
            if chars[i] == "\n" { cursorLine += 1; cursorColumn = 0 } else { cursorColumn += 1 }
        }

        let lines = value.components(separatedBy: "\n")
        var rows: [any View] = []
        for (index, line) in lines.enumerated() {
            let gutter = Text(content: "│ ").forgroundColor(focused ? .cyan : .eight_bit(240))
            if focused && index == cursorLine {
                let lineChars = Array(line)
                let col = Swift.min(cursorColumn, lineChars.count)
                let before = String(lineChars[0..<col])
                let cursorChar = col < lineChars.count ? String(lineChars[col]) : " "
                let after = col < lineChars.count ? String(lineChars[(col + 1)...]) : ""

                var cells: [any View] = [gutter]
                if !before.isEmpty { cells.append(Text(content: before)) }
                cells.append(Text(content: cursorChar).background(.white).forgroundColor(.black))
                if !after.isEmpty { cells.append(Text(content: after)) }
                rows.append(HStack(spacing: 0) { Group(contents: cells) })
            } else {
                rows.append(HStack(spacing: 0) {
                    Group(contents: [gutter, Text(content: line)])
                })
            }
        }

        // With a fixed height, scroll to follow the cursor line by composing a
        // controlled ``ScrollView`` (same viewport machinery as List/Table);
        // otherwise grow to fit every line.
        let node: RenderNode
        if let height, rows.count > height {
            let offset = FocusCoordinator.shared.editorScrollOffset(id: id, cursorLine: cursorLine, viewport: height, totalLines: rows.count)
            node = ScrollView(height: height, offset: offset, focused: focused, showsIndicators: true, content: rows).makeNode()
        } else {
            node = VStack(alignment: .leading, children: rows).makeNode()
        }
        return header.isEmpty ? node : node.applyingHeader(header)
    }
}
