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
    // Value-range controls (``Slider``): a bound Double plus the range and the
    // per-keypress step, routed through ``handleSlider``.
    private var sliderBindings: [String: Binding<Double>] = [:]
    private var sliderRanges: [String: ClosedRange<Double>] = [:]
    private var sliderSteps: [String: Double] = [:]
    // Scroll views: the current vertical offset plus the viewport / content
    // heights needed to clamp it, all keyed by scroll-view id.
    private var scrollOffsets: [String: Int] = [:]
    private var scrollViewportHeights: [String: Int] = [:]
    private var scrollContentHeights: [String: Int] = [:]
    private var scrollIsHorizontal: [String: Bool] = [:]
    // Selectable lists (``List``): a selected-row binding, the row count, and —
    // when the list scrolls — the viewport height and current row offset.
    private var listSelections: [String: Binding<Int?>] = [:]
    private var listCounts: [String: Int] = [:]
    private var listViewports: [String: Int] = [:]
    private var listOffsets: [String: Int] = [:]
    // Multi-line editors (``TextEditor``) remember a vertical scroll offset so the
    // view follows the cursor line minimally, keyed by editor id.
    private var editorOffsets: [String: Int] = [:]
    // Multi-line editors also remember a horizontal scroll offset: long lines
    // are never wrapped — the window slides to keep the cursor column visible.
    private var editorHOffsets: [String: Int] = [:]
    // Action controls (``Button``): the closure fired on Return/Space, keyed by id.
    private var buttonActions: [String: () -> Void] = [:]
    private var focusedID: String?
    // The first control to appear is auto-focused, but only once: after the user
    // blurs with Escape we must not silently re-focus it on the next render.
    private var hasAutoFocused = false
    // Set by `prepareForNewLayer()` to the control focused when navigation
    // pushed/popped. If that control re-registers in the next pass (a split
    // view's sidebar link) it silently keeps focus; if it is gone by the end
    // of the pass (a stack layer that was replaced) focus falls back to the
    // new layer's first control.
    private var pendingRefocusID: String?
    // Render-pass bookkeeping: `currentPassIDs` collects the controls lowered
    // during the pass in progress (nil outside a pass); `visibleIDs` is the
    // set from the most recently completed pass — i.e. the controls actually
    // on screen. The idle check consults it: while a control is visible the
    // user still has something to do, so the session stays alive.
    private var currentPassIDs: Set<String>?
    private var visibleIDs: Set<String> = []
    // Render passes can nest (a one-shot `renderString()` lowered inside a
    // session render); only the outermost bracket owns the pass.
    private var passDepth = 0
    // While > 0, register* calls are ignored: the controls still render (as
    // unfocused, inert views) but never join the focus ring or the visible
    // set. Navigation containers use this to disable the layers beneath the
    // active one.
    private var suppressDepth = 0

    // The slider whose track a left press captured: while held, every drag
    // report re-maps the pointer's column onto the track, so the thumb
    // follows the pointer. Cleared on release (or a press elsewhere).
    private var mouseDragSliderID: String?

    // Momentum scrolling: a repeating timer that continues advancing the
    // scroll offset after the pointing device gesture ends. The timer fires
    // every 16 ms (≈ 60 fps) with a decaying velocity, giving the same
    // "flick" feel as native scroll views. A new gesture cancels any in-
    // flight momentum and restarts it from the new velocity.
    private var momentumTimer: DispatchSourceTimer?
    private var momentumScrollID: String?
    private var momentumVelocity: Double = 0

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

    // MARK: - Render-pass tracking

    /// Marks the start of a render pass; registrations until
    /// ``endRenderPass()`` define the controls visible in the new frame.
    func beginRenderPass() {
        lock.lock()
        passDepth += 1
        let outermost = passDepth == 1
        if outermost { currentPassIDs = [] }
        lock.unlock()
        // The hit-region registry double-buffers per pass in lockstep.
        if outermost { MouseTargetRegistry.shared.beginPass() }
        // Clear focused values so stale entries from removed views don't persist.
        if outermost { FocusedValuesStore.shared.clear() }
    }

    /// Marks the end of a render pass, publishing the visible-control set.
    func endRenderPass() {
        lock.lock()
        passDepth = Swift.max(0, passDepth - 1)
        guard passDepth == 0 else { lock.unlock(); return }
        MouseTargetRegistry.shared.endPass()
        visibleIDs = currentPassIDs ?? []
        currentPassIDs = nil
        // A sticky refocus that no registration claimed: the control focused
        // before the navigation push is gone from the new frame. Fire its
        // unfocus hook and fall back to the new layer's first control.
        if let pending = pendingRefocusID {
            pendingRefocusID = nil
            focusOnUnfocus[pending]?()
            if focusedID == nil, let first = order.first {
                hasAutoFocused = true
                setFocus(to: first, writeback: false)
            }
        }
        lock.unlock()
    }

    /// Whether the most recent frame contains any interactive control.
    var hasVisibleControls: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !visibleIDs.isEmpty
    }

    /// Records a registration in the pass in progress. Must be called with
    /// `lock` held.
    private func noteVisible(_ id: String) {
        currentPassIDs?.insert(id)
    }

    // MARK: - Navigation layer support

    /// Runs `body` with control registration suppressed: any control lowered
    /// inside renders inert — it keeps its (unfocused) appearance but never
    /// joins the focus ring, receives keys, or counts as a visible control.
    ///
    /// Navigation containers wrap the layers beneath the active one in this,
    /// so only the newest layer's controls stay live.
    func withRegistrationSuppressed<T>(_ body: () -> T) -> T {
        lock.lock(); suppressDepth += 1; lock.unlock()
        defer { lock.lock(); suppressDepth = Swift.max(0, suppressDepth - 1); lock.unlock() }
        return body()
    }

    /// Whether registrations are currently suppressed. Must be called with
    /// `lock` held.
    private var isSuppressed: Bool { suppressDepth > 0 }

    /// Whether control registration is currently suppressed — i.e. views are
    /// being lowered for an inert navigation layer. Controls consult this so
    /// inert layers don't record pointer hit regions either.
    var isRegistrationSuppressed: Bool {
        lock.lock(); defer { lock.unlock() }
        return suppressDepth > 0
    }

    /// Clears the focus ring so the next render pass rebuilds it from the
    /// controls that actually register.
    ///
    /// Called when navigation pushes (or pops) a layer. Focus is sticky:
    /// the control focused right now (the activated link) keeps its focus
    /// if it re-registers in the new frame — activating a split view's
    /// sidebar link must not move focus. Only when that control is gone
    /// after the pass (a stack layer that was replaced) does focus move to
    /// the new layer's first control (resolved in ``endRenderPass()``).
    func prepareForNewLayer() {
        lock.lock(); defer { lock.unlock() }
        pendingRefocusID = focusedID
        focusedID = nil
        order.removeAll()
        hasAutoFocused = false
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
        guard !isSuppressed else { return }
        bindings[id] = binding
        submits[id] = onSubmit
        keymaps[id] = keymap
        noteVisible(id)
        if !order.contains(id) { order.append(id) }
        linkFocus(id: id)
    }

    /// Registers a boolean control (a ``Toggle``) in the focus ring.
    ///
    /// Value controls are pure editors — confirmation belongs to a ``Button``
    /// (or a ``TextField``'s `onSubmit`), so no submit hook is taken here.
    ///
    /// - Parameter isOn: The bound boolean the control flips.
    func registerToggle(id: String, isOn: Binding<Bool>) {
        lock.lock(); defer { lock.unlock() }
        guard !isSuppressed else { return }
        boolBindings[id] = isOn
        noteVisible(id)
        if !order.contains(id) { order.append(id) }
        linkFocus(id: id)
    }

    /// Registers an index-selection control (a ``Picker``) in the focus ring.
    ///
    /// - Parameters:
    ///   - selection: The bound selected-option index.
    ///   - count: The number of options (used to wrap and clamp the selection).
    func registerPicker(id: String, selection: Binding<Int>, count: Int) {
        lock.lock(); defer { lock.unlock() }
        guard !isSuppressed else { return }
        intBindings[id] = selection
        optionCounts[id] = count
        noteVisible(id)
        if !order.contains(id) { order.append(id) }
        linkFocus(id: id)
    }

    /// Registers a value-range control (a ``Slider``) in the focus ring.
    ///
    /// - Parameters:
    ///   - value: The bound value the control edits.
    ///   - range: The closed range the value is clamped to.
    ///   - step: The amount one arrow keypress moves the value.
    func registerSlider(id: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double) {
        lock.lock(); defer { lock.unlock() }
        guard !isSuppressed else { return }
        sliderBindings[id] = value
        sliderRanges[id] = range
        sliderSteps[id] = step
        noteVisible(id)
        if !order.contains(id) { order.append(id) }
        linkFocus(id: id)
    }

    /// Registers an action control (a ``Button``) in the focus ring.
    ///
    /// - Parameter action: Called when <kbd>Return</kbd> or <kbd>Space</kbd> is
    ///   pressed while focused.
    func registerButton(id: String, action: @escaping () -> Void) {
        lock.lock(); defer { lock.unlock() }
        guard !isSuppressed else { return }
        buttonActions[id] = action
        noteVisible(id)
        if !order.contains(id) { order.append(id) }
        linkFocus(id: id)
    }

    /// Registers a scroll view in the focus ring, recording the geometry needed
    /// to clamp its offset.
    ///
    /// - Parameters:
    ///   - viewportHeight: The number of rows (or columns, for a horizontal
    ///     viewport) visible at once.
    ///   - contentHeight: The full laid-out height (or width) of the scrolled
    ///     content.
    ///   - isHorizontal: Whether the viewport scrolls horizontally. Affects
    ///     which wheel/swipe events are routed here by the pointer handler.
    func registerScroll(id: String, viewportHeight: Int, contentHeight: Int, isHorizontal: Bool = false) {
        lock.lock(); defer { lock.unlock() }
        guard !isSuppressed else { return }
        scrollViewportHeights[id] = viewportHeight
        scrollContentHeights[id] = contentHeight
        scrollIsHorizontal[id] = isHorizontal
        if scrollOffsets[id] == nil { scrollOffsets[id] = 0 }
        // Re-clamp in case the content shrank since the last render.
        scrollOffsets[id] = clampScroll(scrollOffsets[id] ?? 0, id: id)
        noteVisible(id)
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
    func registerList(id: String, selection: Binding<Int?>, count: Int, viewportRows: Int?) {
        lock.lock(); defer { lock.unlock() }
        guard !isSuppressed else { return }
        listSelections[id] = selection
        listCounts[id] = count
        if let viewportRows { listViewports[id] = viewportRows }
        if listOffsets[id] == nil { listOffsets[id] = 0 }
        noteVisible(id)
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

    /// The horizontal scroll offset for a multi-line editor, adjusted to keep
    /// `cursorColumn` inside a `viewport`-column window. Like the vertical
    /// offset, it is remembered per id and moves minimally — only when the
    /// cursor would leave the window.
    ///
    /// `totalColumns` is the columns the content can occupy (the longest
    /// line plus one, so the block cursor fits at the end of that line).
    func editorHorizontalOffset(id: String, cursorColumn: Int, viewport: Int, totalColumns: Int) -> Int {
        lock.lock(); defer { lock.unlock() }
        guard viewport > 0 else { return 0 }
        var offset = editorHOffsets[id] ?? 0
        if cursorColumn < offset { offset = cursorColumn }
        else if cursorColumn >= offset + viewport { offset = cursorColumn - viewport + 1 }
        let maxOffset = Swift.max(0, totalColumns - viewport)
        offset = Swift.min(Swift.max(offset, 0), maxOffset)
        editorHOffsets[id] = offset
        return offset
    }

    /// The last horizontal offset stored for `id`, without adjusting it. Used
    /// while the editor is unfocused, so blurring doesn't jump the view.
    func editorHorizontalOffset(for id: String) -> Int {
        lock.lock(); defer { lock.unlock() }
        return editorHOffsets[id] ?? 0
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
        if pendingRefocusID == id {
            // The control focused before a navigation push re-registered in
            // the new frame — it keeps focus with no focus-change callbacks
            // (from the app's point of view, focus never moved).
            pendingRefocusID = nil
            hasAutoFocused = true
            focusedID = id
            return
        }
        if focusedID != id, let requested = focusIsRequested[id], requested() {
            // A programmatic focus request always wins.
            pendingRefocusID = nil
            setFocus(to: id)
            return
        }
        // While a sticky refocus is pending, other controls must not claim
        // auto-focus — the sticky control may register later in this pass.
        guard pendingRefocusID == nil else { return }
        if focusedID == nil && !hasAutoFocused {
            // Auto-focus the very first control once, but don't write the binding
            // (that would clobber a focus the app requested before first render).
            // The "once" guard keeps a deliberate blur (Escape) from re-focusing.
            hasAutoFocused = true
            setFocus(to: id, writeback: false)
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
        let sliderBinding = id.flatMap { sliderBindings[$0] }
        let sliderRange = id.flatMap { sliderRanges[$0] } ?? 0...1
        let sliderStep = id.flatMap { sliderSteps[$0] } ?? 0
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
            return handleToggle(id: id, key: key, binding: toggleBinding)
        }
        if let pickerBinding {
            return handlePicker(id: id, key: key, binding: pickerBinding, count: pickerCount)
        }
        if let sliderBinding {
            return handleSlider(key: key, binding: sliderBinding, range: sliderRange, step: sliderStep)
        }
        if isScroll {
            return handleScroll(id: id, key: key)
        }
        if isList {
            return handleList(id: id, key: key)
        }
        return false
    }

    // MARK: - Pointer handling (called from the runtime, main thread)

    /// Routes a pointer event to the control under it.
    ///
    /// - A left-button press focuses the control and activates it the way its
    ///   primary key would: a ``Button`` fires, a ``Toggle`` flips, a
    ///   ``Picker`` advances, a ``List`` selects the clicked row. A click on
    ///   a ``Slider``'s track jumps to the clicked value, and a click inside
    ///   a ``TextField``/``TextEditor``'s text moves the cursor there. A
    ///   press outside every control closes any open menu-bar menu.
    /// - A press on a ``Slider``'s track also captures the pointer: while the
    ///   button stays down, drag reports keep the thumb following the
    ///   pointer's column, and the release lets go.
    /// - The scroll wheel scrolls the ``ScrollView`` or scrolling ``List``
    ///   under the pointer without moving focus.
    ///
    /// - Returns: `true` when the event was consumed (and the display should
    ///   be refreshed).
    @discardableResult
    func handleMouse(_ event: MouseEvent) -> Bool {
        // Reports use absolute screen coordinates; hit regions live in frame
        // coordinates. Full-screen frames start at row 0; an inline frame's
        // origin was resolved from a cursor-position report.
        let column = event.column
        let row = event.row - MouseTargetRegistry.shared.frameOriginRow

        switch event.kind {
        case .scrollUp, .scrollDown:
            // Vertical wheel: step 3 cells per tick for a comfortable feel.
            // Routes to any scroll view under the pointer regardless of axis,
            // so vertical scroll also drives horizontal viewports on terminals
            // that do not forward horizontal swipe events.
            let delta = event.kind == .scrollUp ? -3 : 3
            for region in MouseTargetRegistry.shared.hits(atColumn: column, row: row) {
                let (id, role) = MouseTargetRegistry.parseRegionID(region.id)
                guard role == nil else { continue }
                if wheelScroll(id: id, by: delta) {
                    launchMomentum(id: id, velocity: Double(delta))
                    return true
                }
            }
            return false
        case .scrollLeft, .scrollRight:
            // Horizontal swipe: step 3 columns per tick, routed only to
            // horizontal scroll views. Works on terminals that send button
            // codes 66/67 (iTerm2, kitty, WezTerm, etc.).
            let delta = event.kind == .scrollLeft ? 3 : -3
            for region in MouseTargetRegistry.shared.hits(atColumn: column, row: row) {
                let (id, role) = MouseTargetRegistry.parseRegionID(region.id)
                guard role == nil else { continue }
                if wheelScrollHorizontal(id: id, by: delta) {
                    launchMomentum(id: id, velocity: Double(delta))
                    return true
                }
            }
            return false
        case .press(.left):
            // A new press supersedes any capture still held from a previous
            // one (its release may have been lost to a dropped report).
            lock.lock(); mouseDragSliderID = nil; lock.unlock()
            for region in MouseTargetRegistry.shared.hits(atColumn: column, row: row) {
                let (id, role) = MouseTargetRegistry.parseRegionID(region.id)
                if let role {
                    if activatePart(of: id, role: role, rect: region.rect, column: column, row: row) {
                        return true
                    }
                } else if activate(id: id, rect: region.rect, column: column, row: row) {
                    return true
                }
            }
            // A press on empty space closes an open menu-bar menu, the way a
            // click outside a menu does on a desktop.
            return MenuBarCoordinator.shared.closeIfOpen()
        case .drag(.left):
            // A drag captured by a slider's track: keep the thumb on the
            // pointer's column, tracking the control's *current* rectangle
            // (gaining focus on the press may have shifted it).
            lock.lock(); let dragID = mouseDragSliderID; lock.unlock()
            guard let dragID,
                  let track = MouseTargetRegistry.shared.region(
                      withID: MouseTargetRegistry.regionID(control: dragID, role: MouseTargetRegistry.trackRole))
            else { return false }
            return setSliderValue(id: dragID, trackRect: track.rect, column: column)
        case .release:
            // The button came up: end any capture. Nothing changed on screen.
            lock.lock(); mouseDragSliderID = nil; lock.unlock()
            return false
        case .press, .drag, .move:
            return false
        }
    }

    /// Scrolls any wheel-scrollable control (``ScrollView`` or scrolling
    /// ``List``) by `delta` cells, clamped. Returns `false` when `id` doesn't
    /// scroll. Used for vertical wheel events, which drive any scroll view
    /// regardless of axis.
    private func wheelScroll(id: String, by delta: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        if scrollViewportHeights[id] != nil {
            scrollOffsets[id] = clampScroll((scrollOffsets[id] ?? 0) + delta, id: id)
            return true
        }
        if let viewport = listViewports[id], viewport > 0 {
            let count = listCounts[id] ?? 0
            let maxOffset = Swift.max(0, count - viewport)
            listOffsets[id] = Swift.min(Swift.max((listOffsets[id] ?? 0) + delta, 0), maxOffset)
            return true
        }
        return false
    }

    /// Scrolls a horizontal ``ScrollView`` by `delta` columns, clamped.
    /// Returns `false` when `id` is not a horizontal scroll view. Used for
    /// horizontal swipe events from terminals that forward them (codes 66/67).
    private func wheelScrollHorizontal(id: String, by delta: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard scrollViewportHeights[id] != nil, scrollIsHorizontal[id] == true else { return false }
        scrollOffsets[id] = clampScroll((scrollOffsets[id] ?? 0) + delta, id: id)
        return true
    }

    /// Begins or resets a momentum-scroll animation for `id`.
    ///
    /// Call immediately after a successful wheel/swipe scroll. The timer fires
    /// every ~16 ms (60 fps) starting 80 ms after this call, advancing the
    /// offset with a velocity that decays by 22 % each frame. A new gesture
    /// cancels any in-flight momentum by replacing the timer.
    ///
    /// Must be called on the main thread (same thread as the timer handler).
    private func launchMomentum(id: String, velocity: Double) {
        momentumTimer?.cancel()
        momentumScrollID = id
        // Boost the initial velocity so the post-gesture "flick" extends the
        // effective scroll range without changing the per-event delta.
        momentumVelocity = velocity * 2.2
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 0.08,
                       repeating: .milliseconds(16),
                       leeway: .milliseconds(2))
        timer.setEventHandler { [weak self] in
            guard let self, self.momentumScrollID == id else { return }
            self.momentumVelocity *= 0.78
            let step = Int(self.momentumVelocity.rounded())
            guard step != 0, self.momentumVelocity.magnitude >= 0.3 else {
                self.momentumTimer?.cancel()
                self.momentumTimer = nil
                self.momentumScrollID = nil
                return
            }
            self.lock.lock()
            if self.scrollViewportHeights[id] != nil {
                self.scrollOffsets[id] = self.clampScroll((self.scrollOffsets[id] ?? 0) + step, id: id)
            } else if let viewport = self.listViewports[id], viewport > 0 {
                let count = self.listCounts[id] ?? 0
                let maxOff = Swift.max(0, count - viewport)
                self.listOffsets[id] = Swift.min(Swift.max((self.listOffsets[id] ?? 0) + step, 0), maxOff)
            }
            self.lock.unlock()
            AppRuntime.shared?.scheduleRender()
        }
        timer.resume()
        momentumTimer = timer
    }

    /// Focuses the clicked control and performs its primary action. Returns
    /// `false` when `id` is not (or no longer) a registered control.
    ///
    /// `column`/`row` are in frame coordinates, the same space as `rect`.
    private func activate(id: String, rect: Rect, column: Int, row: Int) -> Bool {
        lock.lock()
        guard order.contains(id) else { lock.unlock(); return false }
        setFocus(to: id)
        let buttonAction = buttonActions[id]
        let toggleBinding = boolBindings[id]
        let pickerBinding = intBindings[id]
        let pickerCount = optionCounts[id] ?? 0
        let listBinding = listSelections[id]
        let listCount = listCounts[id] ?? 0
        let listViewport = listViewports[id]
        let listOffset = listOffsets[id] ?? 0
        lock.unlock()

        // Act outside the lock: actions and binding setters run user code
        // (and re-renders) that may re-enter the coordinator.
        if let buttonAction {
            buttonAction()
            return true
        }
        if let toggleBinding {
            toggleBinding.wrappedValue.toggle()
            return true
        }
        if let pickerBinding, pickerCount > 0 {
            // A click steps to the next option, like Space.
            let current = Swift.min(Swift.max(pickerBinding.wrappedValue, 0), pickerCount - 1)
            pickerBinding.wrappedValue = (current + 1) % pickerCount
            return true
        }
        if let listBinding, listCount > 0 {
            // Map the clicked row to a list row — only when every row occupies
            // exactly one line, which is when the control's height matches the
            // rows on screen (styles that add chrome rows opt out naturally).
            let visibleRows = listViewport ?? listCount
            if rect.size.height == visibleRows {
                let target = row - rect.minRow + (listViewport != nil ? listOffset : 0)
                if target >= 0 && target < listCount {
                    listBinding.wrappedValue = target
                }
            }
            return true
        }
        // Text fields, editors, scroll views: the click just moves focus.
        return true
    }

    /// Focuses the control owning a clicked sub-region and maps the click to
    /// a position within it: a slider's track sets the value, a text run sets
    /// the cursor. Returns `false` when the owner is no longer registered.
    ///
    /// `column`/`row` are in frame coordinates, the same space as `rect`.
    private func activatePart(of id: String, role: String, rect: Rect, column: Int, row: Int) -> Bool {
        lock.lock()
        guard order.contains(id) else { lock.unlock(); return false }
        setFocus(to: id)
        let isSlider = sliderBindings[id] != nil
        let textBinding = bindings[id]
        let hOffset = editorHOffsets[id] ?? 0
        lock.unlock()

        if role == MouseTargetRegistry.trackRole, isSlider {
            // The press captures the pointer: until the release, drag reports
            // keep re-mapping the column onto the track (see handleMouse).
            lock.lock(); mouseDragSliderID = id; lock.unlock()
            _ = setSliderValue(id: id, trackRect: rect, column: column)
            return true
        }

        if role == MouseTargetRegistry.textRole, let textBinding {
            // Single-line field: the clicked column, in display cells, maps
            // to a character index (wide characters span two cells).
            let index = Self.characterIndex(in: textBinding.wrappedValue, atVisibleColumn: column - rect.minColumn)
            lock.lock(); cursors[id] = index; lock.unlock()
            return true
        }

        if role.hasPrefix("line:"), let textBinding, let line = Int(role.dropFirst("line:".count)) {
            // Editor line: the region starts at the visible text (after the
            // gutter), horizontally scrolled by the editor's window offset.
            // The editor addresses columns in characters, matching its layout.
            let lines = textBinding.wrappedValue.components(separatedBy: "\n")
            guard line >= 0, line < lines.count else { return true }
            let clicked = Swift.max(0, column - rect.minColumn)
            let target = Swift.min(hOffset + clicked, lines[line].count)
            var flat = target
            for l in lines[0..<line] { flat += l.count + 1 }
            lock.lock(); cursors[id] = flat; lock.unlock()
            return true
        }

        // Unknown role: the click at least focused the owner.
        return true
    }

    /// Sets a slider's value from a pointer position on its track, snapping
    /// to the keyboard step and clamping to the range. Shared by the initial
    /// press and every subsequent drag report while the pointer is captured.
    ///
    /// Inverts the thumb placement (`thumbIndex = round(fraction × (w-1))`),
    /// with the pointer's column clamped to the track — dragging past either
    /// end pins the value there, like any desktop slider.
    ///
    /// - Returns: `false` when `id` no longer has a slider binding.
    private func setSliderValue(id: String, trackRect: Rect, column: Int) -> Bool {
        lock.lock()
        let binding = sliderBindings[id]
        let range = sliderRanges[id] ?? 0...1
        let step = sliderSteps[id] ?? 0
        lock.unlock()
        guard let binding else { return false }

        let width = trackRect.size.width
        let span = range.upperBound - range.lowerBound
        guard width > 1, span > 0 else { return true }
        let index = Double(Swift.min(Swift.max(column - trackRect.minColumn, 0), width - 1))
        var target = range.lowerBound + index / Double(width - 1) * span
        if step > 0 {
            // Snap to the keyboard step so the pointer lands on a value the
            // arrows can reach.
            target = range.lowerBound + (((target - range.lowerBound) / step).rounded() * step)
        }
        binding.wrappedValue = Swift.min(Swift.max(target, range.lowerBound), range.upperBound)
        return true
    }

    /// The character index a click at `column` display cells into `text`
    /// addresses. Wide characters occupy two cells; a click past the end
    /// returns `text.count` (cursor after the last character).
    static func characterIndex(in text: String, atVisibleColumn column: Int) -> Int {
        guard column > 0 else { return 0 }
        var cell = 0
        for (index, character) in text.enumerated() {
            let width = TextMetrics.width(of: character)
            if cell + width > column { return index }
            cell += width
        }
        return text.count
    }

    /// Moves the selection of a focused list: Up/Down step one row (clamped),
    /// Home/End jump to the ends. When the list scrolls, the offset follows so
    /// the selected row stays visible.
    private func handleList(id: String, key: KeyEvent) -> Bool {
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
    /// Right = off/No); `y`/`n` set it explicitly.
    private func handleToggle(id: String, key: KeyEvent, binding: Binding<Bool>) -> Bool {
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
        default:
            return false
        }
    }

    /// Applies a key to a focused index-selection control.
    ///
    /// Left/Up select the previous option, Right/Down/Space the next (both
    /// wrap), and a digit `1`–`9` jumps to that option.
    private func handlePicker(id: String, key: KeyEvent, binding: Binding<Int>, count: Int) -> Bool {
        guard count > 0 else { return false }
        let current = Swift.min(Swift.max(binding.wrappedValue, 0), count - 1)
        switch key {
        case .left, .up:
            binding.wrappedValue = (current - 1 + count) % count
            return true
        case .right, .down, .character(" "):
            binding.wrappedValue = (current + 1) % count
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

    /// Applies a key to a focused value-range control.
    ///
    /// Left/Down step the value down and Right/Up step it up (clamped to the
    /// range); Home/End jump to the minimum/maximum.
    private func handleSlider(key: KeyEvent, binding: Binding<Double>, range: ClosedRange<Double>, step: Double) -> Bool {
        let current = Swift.min(Swift.max(binding.wrappedValue, range.lowerBound), range.upperBound)
        let target: Double
        switch key {
        case .left, .down:  target = current - step
        case .right, .up:   target = current + step
        case .home:         target = range.lowerBound
        case .end:          target = range.upperBound
        default:            return false
        }
        binding.wrappedValue = Swift.min(Swift.max(target, range.lowerBound), range.upperBound)
        return true
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
        MouseTargetRegistry.shared.reset()
        lock.lock(); defer { lock.unlock() }
        currentPassIDs = nil
        visibleIDs.removeAll()
        order.removeAll()
        cursors.removeAll()
        bindings.removeAll()
        submits.removeAll()
        keymaps.removeAll()
        boolBindings.removeAll()
        intBindings.removeAll()
        optionCounts.removeAll()
        sliderBindings.removeAll()
        sliderRanges.removeAll()
        sliderSteps.removeAll()
        scrollOffsets.removeAll()
        scrollViewportHeights.removeAll()
        scrollContentHeights.removeAll()
        scrollIsHorizontal.removeAll()
        listSelections.removeAll()
        listCounts.removeAll()
        listViewports.removeAll()
        listOffsets.removeAll()
        editorOffsets.removeAll()
        editorHOffsets.removeAll()
        buttonActions.removeAll()
        pendingFocus.removeAll()
        focusOnFocus.removeAll()
        focusOnUnfocus.removeAll()
        focusIsRequested.removeAll()
        focusedID = nil
        hasAutoFocused = false
        pendingRefocusID = nil
        passDepth = 0
        mouseDragSliderID = nil
        momentumTimer?.cancel()
        momentumTimer = nil
        momentumScrollID = nil
        momentumVelocity = 0
    }
}
