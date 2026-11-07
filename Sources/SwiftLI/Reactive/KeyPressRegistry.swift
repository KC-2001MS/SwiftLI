//
//  KeyPressRegistry.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/11/07.
//

import Foundation

/// Collects the ``View/onKeyPress(action:)`` handlers lowered during a render
/// pass and routes the keys the focused control leaves unhandled to them.
///
/// Handlers are gathered per pass the same way ``FocusCoordinator`` gathers
/// controls: the pass in progress collects, and the set is published when
/// the pass ends, so a key is only ever offered to handlers that are actually
/// on screen. Handlers inside an inert navigation layer (registration
/// suppressed) never register.
///
/// Dispatch order — the first handler to return ``KeyPress/Result/handled``
/// stops propagation:
/// 1. The handlers enclosing the focused control, innermost first — the
///    same walk up the hierarchy SwiftUI performs.
/// 2. Every other handler in the frame, innermost first in document order,
///    so a screen-wide shortcut works no matter which control has focus.
final class KeyPressRegistry: @unchecked Sendable {

    /// The process-wide registry used by the reactive runtime.
    static let shared = KeyPressRegistry()

    typealias Handler = (KeyPress) -> KeyPress.Result

    private let lock = NSLock()

    // The pass in progress (meaningful only while `inPass` is true).
    private var inPass = false
    private var nextToken = 0
    private var passHandlers: [Int: Handler] = [:]
    /// Tokens in post-order — a handler is appended once the content it wraps
    /// has lowered, so inner handlers precede outer ones.
    private var passOrder: [Int] = []
    /// The handlers whose content is being lowered right now, outermost first.
    private var stack: [Int] = []
    /// For each control registered this pass, the handler chain enclosing it
    /// (a snapshot of `stack` at registration time).
    private var passControlAncestors: [String: [Int]] = [:]

    // The most recently completed pass — the handlers actually on screen.
    private var handlers: [Int: Handler] = [:]
    private var order: [Int] = []
    private var controlAncestors: [String: [Int]] = [:]

    private init() {}

    // MARK: Render-pass tracking

    /// Starts collecting handlers for a new frame. Called by
    /// ``FocusCoordinator/beginRenderPass()`` for the outermost pass.
    func beginPass() {
        lock.lock(); defer { lock.unlock() }
        inPass = true
        passHandlers.removeAll(keepingCapacity: true)
        passOrder.removeAll(keepingCapacity: true)
        stack.removeAll(keepingCapacity: true)
        passControlAncestors.removeAll(keepingCapacity: true)
    }

    /// Publishes the handlers collected since ``beginPass()``.
    func endPass() {
        lock.lock(); defer { lock.unlock() }
        guard inPass else { return }
        inPass = false
        handlers = passHandlers
        order = passOrder
        controlAncestors = passControlAncestors
    }

    /// Registers `handler` as enclosing the content lowered until the matching
    /// ``pop(_:)``. Returns a token for `pop`, or `nil` outside a pass (a
    /// bare `measure()`), in which case nothing was registered.
    func push(_ handler: @escaping Handler) -> Int? {
        lock.lock(); defer { lock.unlock() }
        guard inPass else { return nil }
        nextToken += 1
        let token = nextToken
        passHandlers[token] = handler
        stack.append(token)
        return token
    }

    /// Finishes the registration begun by ``push(_:)``: the handler's content
    /// has lowered, so it now takes its (post-order) place in the dispatch
    /// order.
    func pop(_ token: Int?) {
        guard let token else { return }
        lock.lock(); defer { lock.unlock() }
        guard inPass else { return }
        if let index = stack.lastIndex(of: token) { stack.remove(at: index) }
        passOrder.append(token)
    }

    /// Records the handler chain enclosing control `id` at the point it
    /// registers with ``FocusCoordinator``. Takes only this registry's lock.
    func noteControl(_ id: String) {
        lock.lock(); defer { lock.unlock() }
        guard inPass, !stack.isEmpty else { return }
        passControlAncestors[id] = stack
    }

    /// Whether the current frame contains any key-press handler. The idle
    /// check consults it: while a handler is on screen the user still has a
    /// key to press, so the session stays alive.
    var hasHandlers: Bool {
        lock.lock(); defer { lock.unlock() }
        return !order.isEmpty
    }

    // MARK: Dispatch (called from the runtime, main thread)

    /// Offers `event` to the published handlers (see the type overview for
    /// the order) and reports whether one consumed it. Events that are not
    /// key presses (pointer reports, terminal replies) are never offered.
    ///
    /// - Parameter focusedControl: The id of the focused control, whose
    ///   enclosing handlers are tried first.
    @discardableResult
    func dispatch(_ event: KeyEvent, focusedControl: String?) -> Bool {
        guard let press = KeyPress(event) else { return false }

        lock.lock()
        let handlers = handlers
        let order = order
        let ancestors = focusedControl.flatMap { controlAncestors[$0] } ?? []
        lock.unlock()

        // Innermost ancestor first, then everything else in post-order.
        var sequence = Array(ancestors.reversed())
        let seen = Set(sequence)
        sequence.append(contentsOf: order.filter { !seen.contains($0) })

        for token in sequence {
            guard let handler = handlers[token] else { continue }
            if handler(press) == .handled { return true }
        }
        return false
    }

    /// Clears every handler (called when the runtime tears down).
    func reset() {
        lock.lock(); defer { lock.unlock() }
        inPass = false
        passHandlers.removeAll()
        passOrder.removeAll()
        stack.removeAll()
        passControlAncestors.removeAll()
        handlers.removeAll()
        order.removeAll()
        controlAncestors.removeAll()
    }
}
