//
//  FocusCoordinator.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/07.
//

import Foundation

/// Tracks which ``TextField`` is focused and owns the per-field cursor state.
///
/// The coordinator is the bridge between raw keyboard input and the declarative
/// views. Each render, every visible `TextField` registers its identity and its
/// `Binding<String>` here; when a key arrives, the runtime forwards it to the
/// coordinator, which applies the edit to the focused field's binding (driving a
/// re-render) or moves focus.
///
/// Text is owned by each field's binding (the single source of truth); the
/// coordinator only holds UI state — focus and cursor offsets — keyed by field id.
final class FocusCoordinator: @unchecked Sendable {

    /// The process-wide coordinator used by the reactive runtime.
    static let shared = FocusCoordinator()

    private let lock = NSLock()
    private var order: [String] = []
    private var cursors: [String: Int] = [:]
    private var bindings: [String: Binding<String>] = [:]
    private var submits: [String: () -> Void] = [:]
    private var keymaps: [String: TextInputKeymap] = [:]
    // Boolean controls (``Toggle``) live alongside text fields in the same focus
    // ring; they route keys through ``handleToggle`` instead of the text keymap.
    private var boolBindings: [String: Binding<Bool>] = [:]
    // Index-selection controls (``Picker``): a selected-index binding plus the
    // number of options, routed through ``handlePicker``.
    private var intBindings: [String: Binding<Int>] = [:]
    private var optionCounts: [String: Int] = [:]
    // Scroll views: the current vertical offset plus the viewport / content
    // heights needed to clamp it, all keyed by scroll-view id.
    private var scrollOffsets: [String: Int] = [:]
    private var scrollViewportHeights: [String: Int] = [:]
    private var scrollContentHeights: [String: Int] = [:]
    // Selectable lists (``List``): a selected-row binding, the row count, and —
    // when the list scrolls — the viewport height and current row offset.
    private var listSelections: [String: Binding<Int?>] = [:]
    private var listCounts: [String: Int] = [:]
    private var listViewports: [String: Int] = [:]
    private var listOffsets: [String: Int] = [:]
    // Multi-line editors (``TextEditor``) remember a vertical scroll offset so the
    // view follows the cursor line minimally, keyed by editor id.
    private var editorOffsets: [String: Int] = [:]
    // Action controls (``Button``): the closure fired on Return/Space, keyed by id.
    private var buttonActions: [String: () -> Void] = [:]
    private var focusedID: String?
    // The first control to appear is auto-focused, but only once: after the user
    // blurs with Escape we must not silently re-focus it on the next render.
    private var hasAutoFocused = false

    // `@FocusState` integration. Each `.focused()` modifier pushes its callbacks
    // while its control is lowered; the control's registration links them to its
    // id. `onFocus`/`onUnfocus` sync the binding on focus changes; `isRequested`
    // lets the app move focus programmatically.
    private typealias FocusHooks = (onFocus: @Sendable () -> Void, onUnfocus: @Sendable () -> Void, isRequested: @Sendable () -> Bool)
    private var pendingFocus: [FocusHooks] = []
    private var focusOnFocus: [String: @Sendable () -> Void] = [:]
    private var focusOnUnfocus: [String: @Sendable () -> Void] = [:]
    private var focusIsRequested: [String: @Sendable () -> Bool] = [:]

    private init() {}

    // MARK: - @FocusState bridging

    /// Pushes the `.focused()` callbacks that the next control registration will
    /// adopt. Balanced by ``popFocus()``.
    func pushFocus(onFocus: @escaping @Sendable () -> Void, onUnfocus: @escaping @Sendable () -> Void, isRequested: @escaping @Sendable () -> Bool) {
        lock.lock(); pendingFocus.append((onFocus, onUnfocus, isRequested)); lock.unlock()
    }

    /// Pops the most recently pushed `.focused()` callbacks.
    func popFocus() {
        lock.lock(); if !pendingFocus.isEmpty { pendingFocus.removeLast() }; lock.unlock()
    }

    // MARK: - Registration (called from TextField.makeNode)

    /// Registers a field for this render pass, remembering its latest binding.
    ///
    /// The first field ever registered becomes focused automatically. Repeated
    /// registrations of the same id (a field is lowered multiple times per
    /// frame) are idempotent.
    ///
    /// - Parameter keymap: The field's ``TextInputKeymap`` — the style that
    ///   defines its key bindings. ``TextField`` passes a ``SingleLineKeymap``
    ///   (Return submits); ``TextEditor`` passes a ``MultiLineKeymap`` (Return
    ///   inserts a newline, up/down move between lines).
    func register(id: String, binding: Binding<String>, onSubmit: (() -> Void)?, keymap: TextInputKeymap = SingleLineKeymap()) {
        lock.lock(); defer { lock.unlock() }
        bindings[id] = binding
        submits[id] = onSubmit
        keymaps[id] = keymap
        if !order.contains(id) { order.append(id) }
        linkFocus(id: id)
    }

    /// Registers a boolean control (a ``Toggle``) in the focus ring.
    ///
    /// - Parameters:
    ///   - isOn: The bound boolean the control flips.
    ///   - onSubmit: Called when <kbd>Return</kbd> is pressed while focused.
    func registerToggle(id: String, isOn: Binding<Bool>, onSubmit: (() -> Void)?) {
        lock.lock(); defer { lock.unlock() }
        boolBindings[id] = isOn
        submits[id] = onSubmit
        if !order.contains(id) { order.append(id) }
        linkFocus(id: id)
    }

    /// Registers an index-selection control (a ``Picker``) in the focus ring.
    ///
    /// - Parameters:
    ///   - selection: The bound selected-option index.
    ///   - count: The number of options (used to wrap and clamp the selection).
    ///   - onSubmit: Called when <kbd>Return</kbd> is pressed while focused.
    func registerPicker(id: String, selection: Binding<Int>, count: Int, onSubmit: (() -> Void)?) {
        lock.lock(); defer { lock.unlock() }
        intBindings[id] = selection
        optionCounts[id] = count
        submits[id] = onSubmit
        if !order.contains(id) { order.append(id) }
        linkFocus(id: id)
    }

    /// Registers an action control (a ``Button``) in the focus ring.
    ///
    /// - Parameter action: Called when <kbd>Return</kbd> or <kbd>Space</kbd> is
    ///   pressed while focused.
    func registerButton(id: String, action: @escaping () -> Void) {
        lock.lock(); defer { lock.unlock() }
        buttonActions[id] = action
        if !order.contains(id) { order.append(id) }
        linkFocus(id: id)
    }

    /// Registers a scroll view in the focus ring, recording the geometry needed
    /// to clamp its offset.
    ///
    /// - Parameters:
    ///   - viewportHeight: The number of rows visible at once.
    ///   - contentHeight: The full laid-out height of the scrolled content.
    func registerScroll(id: String, viewportHeight: Int, contentHeight: Int, onSubmit: (() -> Void)?) {
        lock.lock(); defer { lock.unlock() }
        scrollViewportHeights[id] = viewportHeight
        scrollContentHeights[id] = contentHeight
        submits[id] = onSubmit
        if scrollOffsets[id] == nil { scrollOffsets[id] = 0 }
        // Re-clamp in case the content shrank since the last render.
        scrollOffsets[id] = clampScroll(scrollOffsets[id] ?? 0, id: id)
        if !order.contains(id) { order.append(id) }
        linkFocus(id: id)
    }

    /// The current (clamped) scroll offset for `id`.
    func scrollOffset(for id: String) -> Int {
        lock.lock(); defer { lock.unlock() }
        return clampScroll(scrollOffsets[id] ?? 0, id: id)
    }

    /// Clamps a scroll offset to `0 ... max(0, content - viewport)`.
    /// Must be called with `lock` held.
    private func clampScroll(_ value: Int, id: String) -> Int {
        let maxOffset = Swift.max(0, (scrollContentHeights[id] ?? 0) - (scrollViewportHeights[id] ?? 0))
        return Swift.min(Swift.max(value, 0), maxOffset)
    }

    /// Registers a selectable list in the focus ring.
    ///
    /// - Parameters:
    ///   - selection: The bound selected-row index (`nil` = nothing selected).
    ///   - count: The number of rows.
    ///   - viewportRows: The visible-row count when the list scrolls, or `nil`
    ///     when the whole list is shown at once.
    func registerList(id: String, selection: Binding<Int?>, count: Int, viewportRows: Int?, onSubmit: (() -> Void)?) {
        lock.lock(); defer { lock.unlock() }
        listSelections[id] = selection
        listCounts[id] = count
        if let viewportRows { listViewports[id] = viewportRows }
        submits[id] = onSubmit
        if listOffsets[id] == nil { listOffsets[id] = 0 }
        if !order.contains(id) { order.append(id) }
        linkFocus(id: id)
    }

    /// The current scroll offset (in rows) for a scrolling list.
    func listOffset(for id: String) -> Int {
        lock.lock(); defer { lock.unlock() }
        return listOffsets[id] ?? 0
    }

    /// The vertical scroll offset for a multi-line editor, adjusted to keep
    /// `cursorLine` inside a `viewport`-row window. The offset is remembered per
    /// id, so the view scrolls minimally — only when the cursor would leave the
    /// window — rather than re-centring on every keystroke.
    func editorScrollOffset(id: String, cursorLine: Int, viewport: Int, totalLines: Int) -> Int {
        lock.lock(); defer { lock.unlock() }
        guard viewport > 0 else { return 0 }
        var offset = editorOffsets[id] ?? 0
        if cursorLine < offset { offset = cursorLine }
        else if cursorLine >= offset + viewport { offset = cursorLine - viewport + 1 }
        let maxOffset = Swift.max(0, totalLines - viewport)
        offset = Swift.min(Swift.max(offset, 0), maxOffset)
        editorOffsets[id] = offset
        return offset
    }

    /// Links any pending `.focused()` callbacks to `id`, then claims focus if no
    /// control is focused yet or if the app has programmatically requested it.
    /// Must be called with `lock` held.
    private func linkFocus(id: String) {
        if let hooks = pendingFocus.last {
            focusOnFocus[id] = hooks.onFocus
            focusOnUnfocus[id] = hooks.onUnfocus
            focusIsRequested[id] = hooks.isRequested
        }
        if focusedID == nil && !hasAutoFocused {
            // Auto-focus the very first control once, but don't write the binding
            // (that would clobber a focus the app requested before first render).
            // The "once" guard keeps a deliberate blur (Escape) from re-focusing.
            hasAutoFocused = true
            setFocus(to: id, writeback: false)
        } else if focusedID != id, let requested = focusIsRequested[id], requested() {
            setFocus(to: id)
        }
    }

    /// Releases focus entirely (Escape), firing the current control's unfocus
    /// callback so a bound `@FocusState` becomes `nil`. Focus returns on Tab.
    func blur() {
        lock.lock(); defer { lock.unlock() }
        guard let old = focusedID else { return }
        focusOnUnfocus[old]?()
        focusedID = nil
    }

    /// Moves focus to `id`. When `writeback` is true, fires the previous
    /// control's unfocus callback and the new control's focus callback so the
    /// bound `@FocusState` follows. Always resets a text cursor to the end.
    /// Must be called with `lock` held.
    private func setFocus(to id: String, writeback: Bool = true) {
        let old = focusedID
        guard old != id else { return }
        focusedID = id
        if writeback {
            if let old { focusOnUnfocus[old]?() }
            focusOnFocus[id]?()
        }
        if let binding = bindings[id] { cursors[id] = binding.wrappedValue.count }
    }

    /// Whether `id` is the currently focused field.
    func isFocused(_ id: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return focusedID == id
    }

    /// The clamped cursor offset for `id`, defaulting to the end of the text.
    func cursor(for id: String) -> Int {
        lock.lock(); defer { lock.unlock() }
        let count = bindings[id]?.wrappedValue.count ?? 0
        let c = cursors[id] ?? count
        return Swift.min(Swift.max(c, 0), count)
    }

    /// The id of the focused field, if any.
    var focused: String? {
        lock.lock(); defer { lock.unlock() }
        return focusedID
    }

    // MARK: - Input handling (called from the runtime, main thread)

    /// Applies a key event to the focused field.
    ///
    /// - Returns: `true` when the event was consumed (and the display should be
    ///   refreshed), `false` when there was no focused field or the key is not
    ///   handled here.
    @discardableResult
    func handle(_ key: KeyEvent) -> Bool {
        lock.lock()
        let id = focusedID
        let toggleBinding = id.flatMap { boolBindings[$0] }
        let pickerBinding = id.flatMap { intBindings[$0] }
        let pickerCount = id.flatMap { optionCounts[$0] } ?? 0
        let textBinding = id.flatMap { bindings[$0] }
        let submit = id.flatMap { submits[$0] }
        let keymap = id.flatMap { keymaps[$0] } ?? SingleLineKeymap()
        let isScroll = id.map { scrollViewportHeights[$0] != nil } ?? false
        let isList = id.map { listSelections[$0] != nil } ?? false
        let buttonAction = id.flatMap { buttonActions[$0] }
        lock.unlock()

        // Nothing focused: Tab / Shift-Tab re-enter the focus ring.
        guard let id else {
            switch key {
            case .tab:     focusNext();     return true
            case .backTab: focusPrevious(); return true
            default:       return false
            }
        }

        // Escape releases focus from any control.
        if key == .escape { blur(); return true }

        // Text controls let their keymap decide *every* key — including Tab, so
        // a multi-line editor can indent (and leave only via Escape) while a
        // single-line field uses Tab to move focus.
        if let binding = textBinding {
            let count = binding.wrappedValue.count
            let currentCursor = Swift.min(Swift.max(cursors[id] ?? count, 0), count)
            switch keymap.command(for: key) {
            case .focusNext:
                focusNext()
                return true
            case .focusPrevious:
                focusPrevious()
                return true
            case .submit:
                submit?()
                return true
            case .cancel, .ignore:
                return false
            case let command:
                let result = TextFieldEditor.apply(command, to: binding.wrappedValue, cursor: currentCursor)
                // Writing the binding schedules a re-render via @State's setter;
                // skip the write for pure cursor moves that don't change the text.
                if result.text != binding.wrappedValue {
                    binding.wrappedValue = result.text
                }
                lock.lock(); cursors[id] = result.cursor; lock.unlock()
                return true
            }
        }

        // Non-text controls (Toggle, Picker, ScrollView): Tab / Shift-Tab move focus.
        switch key {
        case .tab:     focusNext();     return true
        case .backTab: focusPrevious(); return true
        default: break
        }
        if let buttonAction {
            return handleButton(key: key, action: buttonAction)
        }
        if let toggleBinding {
            return handleToggle(id: id, key: key, binding: toggleBinding, submit: submit)
        }
        if let pickerBinding {
            return handlePicker(id: id, key: key, binding: pickerBinding, count: pickerCount, submit: submit)
        }
        if isScroll {
            return handleScroll(id: id, key: key)
        }
        if isList {
            return handleList(id: id, key: key, submit: submit)
        }
        return false
    }

    /// Moves the selection of a focused list: Up/Down step one row (clamped),
    /// Home/End jump to the ends, Return submits. When the list scrolls, the
    /// offset follows so the selected row stays visible.
    private func handleList(id: String, key: KeyEvent, submit: (() -> Void)?) -> Bool {
        lock.lock()
        let count = listCounts[id] ?? 0
        let binding = listSelections[id]
        let current = binding?.wrappedValue ?? -1
        lock.unlock()

        guard count > 0 else { return false }
        let target: Int
        switch key {
        case .up:    target = current < 0 ? 0 : Swift.max(0, current - 1)
        case .down:  target = current < 0 ? 0 : Swift.min(count - 1, current + 1)
        case .home:  target = 0
        case .end:   target = count - 1
        case .enter: submit?(); return true
        default:     return false
        }
        binding?.wrappedValue = target

        // Keep the selection within the viewport for a scrolling list.
        lock.lock()
        if let viewport = listViewports[id], viewport > 0 {
            var offset = listOffsets[id] ?? 0
            if target < offset { offset = target }
            else if target >= offset + viewport { offset = target - viewport + 1 }
            let maxOffset = Swift.max(0, count - viewport)
            listOffsets[id] = Swift.min(Swift.max(offset, 0), maxOffset)
        }
        lock.unlock()
        return true
    }

    /// Scrolls a focused scroll view: Up/Down move one line, Space one viewport,
    /// Home/End jump to the ends. The offset is re-clamped to the content.
    private func handleScroll(id: String, key: KeyEvent) -> Bool {
        lock.lock(); defer { lock.unlock() }
        let current = scrollOffsets[id] ?? 0
        let viewport = scrollViewportHeights[id] ?? 1
        let maxOffset = Swift.max(0, (scrollContentHeights[id] ?? 0) - viewport)
        let target: Int
        switch key {
        // Up/Left step back one, Down/Right forward one — so the same handler
        // drives both a vertical viewport (↑/↓) and a horizontal one (←/→).
        case .up, .left:           target = current - 1
        case .down, .right:        target = current + 1
        case .character(" "):      target = current + viewport
        case .home:                target = 0
        case .end:                 target = maxOffset
        default:                   return false
        }
        scrollOffsets[id] = Swift.min(Swift.max(target, 0), maxOffset)
        return true
    }

    /// Applies a key to a focused action control: Return or Space fires the
    /// button's action.
    private func handleButton(key: KeyEvent, action: () -> Void) -> Bool {
        switch key {
        case .enter, .character(" "):
            action()
            return true
        default:
            return false
        }
    }

    /// Applies a key to a focused boolean control.
    ///
    /// Space flips the value; the arrows select a side (Left = on/Yes,
    /// Right = off/No); `y`/`n` set it explicitly; Return submits.
    private func handleToggle(id: String, key: KeyEvent, binding: Binding<Bool>, submit: (() -> Void)?) -> Bool {
        switch key {
        case .character(" "):
            binding.wrappedValue.toggle()
            return true
        case .left:
            binding.wrappedValue = true
            return true
        case .right:
            binding.wrappedValue = false
            return true
        case .character("y"), .character("Y"):
            binding.wrappedValue = true
            return true
        case .character("n"), .character("N"):
            binding.wrappedValue = false
            return true
        case .enter:
            submit?()
            return true
        default:
            return false
        }
    }

    /// Applies a key to a focused index-selection control.
    ///
    /// Left/Up select the previous option, Right/Down/Space the next (both wrap),
    /// a digit `1`–`9` jumps to that option, and Return submits.
    private func handlePicker(id: String, key: KeyEvent, binding: Binding<Int>, count: Int, submit: (() -> Void)?) -> Bool {
        guard count > 0 else { return false }
        let current = Swift.min(Swift.max(binding.wrappedValue, 0), count - 1)
        switch key {
        case .left, .up:
            binding.wrappedValue = (current - 1 + count) % count
            return true
        case .right, .down, .character(" "):
            binding.wrappedValue = (current + 1) % count
            return true
        case .enter:
            submit?()
            return true
        case .character(let c):
            if let digit = c.wholeNumberValue, digit >= 1, digit <= count {
                binding.wrappedValue = digit - 1
                return true
            }
            return false
        default:
            return false
        }
    }

    /// Moves focus to the next registered field (wrapping around).
    func focusNext() {
        lock.lock(); defer { lock.unlock() }
        guard !order.isEmpty else { return }
        let nextIndex: Int
        if let id = focusedID, let idx = order.firstIndex(of: id) {
            nextIndex = (idx + 1) % order.count
        } else {
            nextIndex = 0
        }
        setFocus(to: order[nextIndex])
    }

    /// Moves focus to the previous registered field (wrapping around).
    func focusPrevious() {
        lock.lock(); defer { lock.unlock() }
        guard !order.isEmpty else { return }
        let prevIndex: Int
        if let id = focusedID, let idx = order.firstIndex(of: id) {
            prevIndex = (idx - 1 + order.count) % order.count
        } else {
            prevIndex = 0
        }
        setFocus(to: order[prevIndex])
    }

    /// Clears all focus/cursor state (called when the runtime tears down).
    func reset() {
        lock.lock(); defer { lock.unlock() }
        order.removeAll()
        cursors.removeAll()
        bindings.removeAll()
        submits.removeAll()
        keymaps.removeAll()
        boolBindings.removeAll()
        intBindings.removeAll()
        optionCounts.removeAll()
        scrollOffsets.removeAll()
        scrollViewportHeights.removeAll()
        scrollContentHeights.removeAll()
        listSelections.removeAll()
        listCounts.removeAll()
        listViewports.removeAll()
        listOffsets.removeAll()
        editorOffsets.removeAll()
        buttonActions.removeAll()
        pendingFocus.removeAll()
        focusOnFocus.removeAll()
        focusOnUnfocus.removeAll()
        focusIsRequested.removeAll()
        focusedID = nil
        hasAutoFocused = false
    }
}
