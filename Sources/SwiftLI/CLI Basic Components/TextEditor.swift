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
/// Long lines are never wrapped: the editor keeps one row per line and
/// **scrolls horizontally** instead — when a line is wider than the terminal,
/// the whole viewport slides to keep the cursor column in view, moving
/// minimally like the vertical cursor-following scroll.
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

    let style: TextStyle
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
        let resolved = placeholder.resolve()
        self.style = .plain
        self.id = id ?? (resolved.isEmpty ? "TextEditor" : resolved)
        self.placeholder = resolved
        self.text = text
        self.tabBehavior = tabBehavior
        self.height = height
    }

    init(style: TextStyle, id: String, placeholder: String, text: Binding<String>, tabBehavior: TabBehavior, height: Int?) {
        self.style = style
        self.id = id
        self.placeholder = placeholder
        self.text = text
        self.tabBehavior = tabBehavior
        self.height = height
    }

    /// The content and behavior of the text editor view.
    public var body: some View {
        EmptyView()
    }

    @_spi(RenderingInternals)
    public func applyingStyle(_ style: TextStyle) -> Self {
        TextEditor(style: self.style.inheriting(style), id: id, placeholder: placeholder, text: text, tabBehavior: tabBehavior, height: height)
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
            return (style.isPlain ? node : node.applyingStyle(style)).asControl(id: id)
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

        // Long lines are never wrapped: the editor keeps one row per line and
        // scrolls horizontally instead, sliding a shared window over every
        // line so the cursor column stays visible (the whole viewport shifts,
        // like a terminal editor in no-wrap mode).
        let gutterWidth = 2
        let resolvedHeight = height ?? EnvironmentStack.current.maxHeight
        let scrollsVertically = lines.count > resolvedHeight
        let contentWidth = Swift.max(1, EnvironmentStack.current.maxWidth - gutterWidth - (scrollsVertically ? 1 : 0))
        // One extra column so the block cursor fits at the end of the longest line.
        let totalColumns = lines.reduce(0) { Swift.max($0, $1.count) } + 1
        let hOffset: Int
        if totalColumns <= contentWidth {
            hOffset = 0
        } else if focused {
            hOffset = FocusCoordinator.shared.editorHorizontalOffset(id: id, cursorColumn: cursorColumn, viewport: contentWidth, totalColumns: totalColumns)
        } else {
            // Keep the last position while blurred, clamped to the current content.
            hOffset = Swift.min(FocusCoordinator.shared.editorHorizontalOffset(for: id), totalColumns - contentWidth)
        }

        var rows: [any View] = []
        for (index, line) in lines.enumerated() {
            let gutter = Text(content: "│ ").forgroundColor(focused ? .cyan : .eight_bit(240))
            let lineChars = Array(line)
            let windowEnd = Swift.min(lineChars.count, hOffset + contentWidth)
            // Each line's visible text (after the gutter) is a pointer
            // sub-region: a click on it moves the cursor to that position.
            func lineRegion(_ content: any View) -> HitRegion {
                HitRegion(controlID: id, role: MouseTargetRegistry.lineRole(index), content: content)
            }
            if focused && index == cursorLine {
                let col = Swift.min(Swift.max(cursorColumn, hOffset), lineChars.count)
                let before = hOffset < col ? String(lineChars[hOffset..<col]) : ""
                let cursorChar = col < lineChars.count ? String(lineChars[col]) : " "
                let after = (col + 1) < windowEnd ? String(lineChars[(col + 1)..<windowEnd]) : ""

                var cells: [any View] = []
                if !before.isEmpty { cells.append(Text(content: before)) }
                cells.append(Text(content: cursorChar).background(.white).forgroundColor(.black))
                if !after.isEmpty { cells.append(Text(content: after)) }
                rows.append(HStack(spacing: 0) {
                    Group(contents: [gutter, lineRegion(HStack(spacing: 0) { Group(contents: cells) })])
                })
            } else {
                let visible = hOffset < lineChars.count ? String(lineChars[hOffset..<windowEnd]) : ""
                // An empty window still gets a one-cell region, so clicking
                // an empty line can land the cursor on it.
                rows.append(HStack(spacing: 0) {
                    Group(contents: [gutter, lineRegion(Text(content: visible.isEmpty ? " " : visible))])
                })
            }
        }

        // With a fixed height, scroll to follow the cursor line by composing a
        // controlled ``ScrollView`` (same viewport machinery as List/Table);
        // otherwise grow to fit every line.
        let node: RenderNode
        if scrollsVertically {
            let offset = FocusCoordinator.shared.editorScrollOffset(id: id, cursorLine: cursorLine, viewport: resolvedHeight, totalLines: rows.count)
            node = ScrollView(height: resolvedHeight, offset: offset, focused: focused, showsIndicators: true, content: rows).makeNode()
        } else {
            node = VStack(alignment: .leading, children: rows).makeNode()
        }
        return (style.isPlain ? node : node.applyingStyle(style)).asControl(id: id)
    }
}
