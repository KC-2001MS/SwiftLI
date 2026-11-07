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
    /// An identity given explicitly, or `nil` to derive one from the label.
    let explicitID: String?
    /// The identity used when none is given — the label, made unique per
    /// position inside a session (see ``ControlIdentity``).
    let fallbackID: String
    /// The identity the control registers under.
    var id: String { ControlIdentity.resolve(explicitID, default: fallbackID) }
    let placeholder: String
    let text: Binding<String>
    let tabBehavior: TabBehavior

    /// Creates a multi-line text editor.
    ///
    /// Constrain the visible rows with ``View/frame(width:height:alignment:)``:
    /// when the text has more lines than fit, the editor scrolls to keep the
    /// cursor line in view (drawing a scrollbar). Unconstrained, it grows to
    /// fit all lines.
    ///
    /// - Parameters:
    ///   - placeholder: Prompt shown when empty and unfocused; also the default identity.
    ///   - text: The bound string to edit (may contain newlines).
    ///   - id: An explicit identity; defaults to the placeholder text.
    ///   - tabBehavior: Whether Tab moves focus (default) or indents (code editor).
    public init(_ placeholder: LocalizedStringKey = "", text: Binding<String>, id: String? = nil, tabBehavior: TabBehavior = .focus) {
        let resolved = placeholder.resolve()
        self.style = .plain
        self.explicitID = id
        self.fallbackID = resolved.isEmpty ? "TextEditor" : resolved
        self.placeholder = resolved
        self.text = text
        self.tabBehavior = tabBehavior
    }

    init(style: TextStyle, explicitID: String?, fallbackID: String, placeholder: String, text: Binding<String>, tabBehavior: TabBehavior) {
        self.style = style
        self.explicitID = explicitID
        self.fallbackID = fallbackID
        self.placeholder = placeholder
        self.text = text
        self.tabBehavior = tabBehavior
    }

    /// The gutter-prefixed lines of the editor (a placeholder row while empty
    /// and unfocused), windowed horizontally to the cursor and scrolled to it
    /// vertically when a height bounds them, hosted as a focusable control
    /// and carrying the editor's own text style.
    public var body: some View {
        let layout = self.layout
        if layout.showsPlaceholder {
            // Empty & unfocused → a single placeholder row.
            HStack(spacing: 0) {
                Text(content: "│ ").foregroundStyle(.eightBit(240))
                Text(content: placeholder).foregroundStyle(.eightBit(240))
            }
        } else if layout.scrollsVertically {
            // With a fixed height, scroll to follow the cursor line by
            // composing a controlled ``ScrollView`` (same viewport machinery
            // as List/Table).
            ScrollView(height: layout.viewportHeight, offset: layout.scrollOffset, focused: layout.focused, content: [
                ForEach(layout.lines) { line in
                    row(line, focused: layout.focused)
                }
            ])
        } else {
            // Otherwise grow to fit every line.
            VStack(alignment: .leading, spacing: 0) {
                ForEach(layout.lines) { line in
                    row(line, focused: layout.focused)
                }
            }
        }
    }

    /// One row: the gutter, then the line's visible text as a pointer
    /// sub-region (a click on it moves the cursor there) — split around a
    /// block cursor on the cursor line.
    @ViewBuilder
    private func row(_ line: LineLayout, focused: Bool) -> some View {
        HStack(spacing: 0) {
            Text(content: "│ ").foregroundStyle(focused ? .cyan : .eightBit(240))
            if let cursor = line.cursor {
                HitRegion(controlID: id, role: MouseTargetRegistry.lineRole(line.index), content: HStack(spacing: 0) {
                    if !line.before.isEmpty {
                        Text(content: line.before)
                    }
                    Text(content: cursor).background(.white).foregroundStyle(.black)
                    if !line.after.isEmpty {
                        Text(content: line.after)
                    }
                })
            } else {
                HitRegion(controlID: id, role: MouseTargetRegistry.lineRole(line.index), content: Text(content: line.before))
            }
        }
    }

    /// Registers the editor for keyboard handling, then lowers ``body`` with
    /// the editor's own text style cascaded onto it as the editor's pointer
    /// footprint.
    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        let keymap = MultiLineKeymap(indentsWithTab: tabBehavior == .indent)
        FocusCoordinator.shared.register(id: id, binding: text, onSubmit: nil, keymap: keymap)
        KeyInputRouter.shared.ensureStarted()
        let node = body.makeNode()
        return (style.isPlain ? node : node.applyingStyle(style)).asControl(id: id)
    }

    /// One row of the editor as laid out for the current pass: its index, the
    /// visible text before the cursor (on any other line, the whole visible
    /// window — a single space when empty), the glyph under the cursor and the
    /// visible text after it (both on the cursor line only).
    private typealias LineLayout = (index: Int, before: String, cursor: String?, after: String)

    /// The editor's rows for the current pass and how they are scrolled.
    /// `showsPlaceholder` is set when the editor is empty and unfocused, in
    /// which case a single placeholder row replaces the lines.
    private typealias Layout = (focused: Bool, showsPlaceholder: Bool, lines: [LineLayout], scrollsVertically: Bool, viewportHeight: Int, scrollOffset: Int)

    /// The layout for this pass: the text laid out for the current focus and
    /// cursor — the cursor located, the shared horizontal window slid to keep
    /// it visible, its on-screen position reported (for the IME), and the
    /// viewport following it vertically.
    private var layout: Layout {
        let focused = FocusCoordinator.shared.isFocused(id)
        let value = text.wrappedValue

        if value.isEmpty && !focused {
            return (focused: focused, showsPlaceholder: true, lines: [], scrollsVertically: false, viewportHeight: 0, scrollOffset: 0)
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
        _TextEditorDebugLog.write("layout id=\(id) focused=\(focused) valueLen=\(value.count) lines=\(lines.count) cursorLine=\(cursorLine) cursorColumn=\(cursorColumn) maxWidth=\(EnvironmentStack.current.maxWidth) maxHeight=\(EnvironmentStack.current.maxHeight)")

        // Long lines are never wrapped: the editor keeps one row per line and
        // scrolls horizontally instead, sliding a shared window over every
        // line so the cursor column stays visible (the whole viewport shifts,
        // like a terminal editor in no-wrap mode).
        let gutterWidth = 2
        // `.frame(height:)` pins `maxHeight`, bounding the visible rows.
        let resolvedHeight = EnvironmentStack.current.maxHeight
        let scrollsVertically = lines.count > resolvedHeight
        let contentWidth = Swift.max(1, EnvironmentStack.current.maxWidth - gutterWidth - (scrollsVertically ? 1 : 0))
        // `hOffset`/`contentWidth` are display *columns*, not characters: a
        // full-width CJK character (kanji/kana) occupies 2 terminal columns,
        // so measuring by character count would let a line's real on-screen
        // width silently exceed `contentWidth` — which the frame's
        // width-truncation then clips, taking whatever was drawn after it
        // (e.g. the scrollbar) with it. `advanceByColumns` below converts
        // between a column offset and the character index it falls on.
        // One extra column so the block cursor fits at the end of the longest line.
        let totalColumns = lines.reduce(0) { Swift.max($0, TextMetrics.visibleWidth($1)) } + 1
        // The cursor's column measured the same way, for the horizontal-scroll
        // math below — `cursorColumn` itself stays a character index, since
        // text mutation (insert/delete) needs that, not a column.
        let cursorLineChars = Array(lines[cursorLine])
        let cursorVisualColumn = TextMetrics.visibleWidth(String(cursorLineChars.prefix(cursorColumn)))
        let hOffset: Int
        if totalColumns <= contentWidth {
            hOffset = 0
        } else if focused {
            hOffset = FocusCoordinator.shared.editorHorizontalOffset(id: id, cursorColumn: cursorVisualColumn, viewport: contentWidth, totalColumns: totalColumns)
        } else {
            // Keep the last position while blurred, clamped to the current content.
            hOffset = Swift.min(FocusCoordinator.shared.editorHorizontalOffset(for: id), totalColumns - contentWidth)
        }

        var rows: [LineLayout] = []
        for (index, line) in lines.enumerated() {
            let lineChars = Array(line)
            // Convert the shared column-based `hOffset`/`contentWidth` into
            // this line's own character-index window: each line maps columns
            // to characters differently depending on how many wide
            // characters it contains before the window.
            let startIdx = Self.advanceByColumns(lineChars, from: 0, budget: hOffset)
            let windowEnd = Self.advanceByColumns(lineChars, from: startIdx, budget: contentWidth)
            if focused && index == cursorLine {
                let col = Swift.min(Swift.max(cursorColumn, startIdx), lineChars.count)
                let before = startIdx < col ? String(lineChars[startIdx..<col]) : ""
                let cursorChar = col < lineChars.count ? String(lineChars[col]) : " "
                let after = (col + 1) < windowEnd ? String(lineChars[(col + 1)..<windowEnd]) : ""
                // The column offset must be the *visible* width, not the
                // character count: full-width CJK characters (kanji/kana —
                // exactly what an IME commits) occupy 2 terminal columns each,
                // so counting characters under-reports the real column
                // whenever any wide character precedes the cursor, placing
                // the real cursor (and so the IME's popup) to the left of
                // where the glyph actually is.
                FocusCoordinator.shared.reportCursor(id: id, regionID: MouseTargetRegistry.regionID(control: id, role: MouseTargetRegistry.lineRole(index)), offset: TextMetrics.visibleWidth(before))
                rows.append((index: index, before: before, cursor: cursorChar, after: after))
            } else {
                let visible = startIdx < lineChars.count ? String(lineChars[startIdx..<windowEnd]) : ""
                // An empty window still gets a one-cell region, so clicking
                // an empty line can land the cursor on it.
                rows.append((index: index, before: visible.isEmpty ? " " : visible, cursor: nil, after: ""))
            }
        }

        // With a fixed height, follow the cursor line.
        let scrollOffset = scrollsVertically
            ? FocusCoordinator.shared.editorScrollOffset(id: id, cursorLine: cursorLine, cursorColumn: cursorColumn, viewport: resolvedHeight, totalLines: rows.count)
            : 0
        _TextEditorDebugLog.write("  -> rows=\(rows.count) scrollsVertically=\(scrollsVertically) contentWidth=\(contentWidth) hOffset=\(hOffset) firstLine=\(lines.first?.debugDescription ?? "nil")")
        return (focused: focused, showsPlaceholder: false, lines: rows, scrollsVertically: scrollsVertically, viewportHeight: resolvedHeight, scrollOffset: scrollOffset)
    }

    /// The index in `chars` at which the cumulative display width of
    /// `chars[start...]` first reaches or exceeds `budget` columns (or
    /// `chars.count` if the whole remainder fits within budget).
    ///
    /// Used to translate a column-based offset/width into the character
    /// index it falls on, since a full-width character occupies 2 columns —
    /// character position and column position only coincide when every
    /// character in between is single-width.
    fileprivate static func advanceByColumns(_ chars: [Character], from start: Int, budget: Int) -> Int {
        guard budget > 0 else { return start }
        var used = 0
        var i = start
        while i < chars.count {
            let w = TextMetrics.width(of: chars[i])
            if used + w > budget { break }
            used += w
            i += 1
        }
        return i
    }
}

// TEMPORARY diagnostic logging — writes to a file (never the terminal itself,
// so it can't interfere with the alt-screen display) to inspect what
// `TextEditor.makeNode()` actually computed during a real interactive
// session, since the bug it's chasing doesn't reproduce under any headless/
// synthetic test harness. Remove once the root cause is found.
enum _TextEditorDebugLog {
    private static let lock = NSLock()
    // Opt-in via `SWIFTLI_TEXTEDITOR_DEBUG=1`: unconditionally appending to a
    // file on every render (two opens, seeks and writes per frame) is far too
    // expensive to leave on, and the message is only built when enabled.
    private static let isEnabled = ProcessInfo.processInfo.environment["SWIFTLI_TEXTEDITOR_DEBUG"] != nil
    static func write(_ message: @autoclosure () -> String) {
        guard isEnabled else { return }
        lock.lock(); defer { lock.unlock() }
        let line = "\(Date()) \(message())\n"
        guard let data = line.data(using: .utf8) else { return }
        let path = "/tmp/texteditor_debug.log"
        if let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile()
            handle.write(data)
            handle.closeFile()
        } else {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }
}
