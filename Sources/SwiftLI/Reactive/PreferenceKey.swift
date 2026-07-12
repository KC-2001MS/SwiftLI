//
//  PreferenceKey.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/12.
//

import Foundation

// MARK: - PreferenceKey

/// A key for a value that flows from child views up to ancestor views,
/// mirroring SwiftUI's `PreferenceKey`.
///
/// Preferences are the upward counterpart to environment values: where the
/// environment propagates values **down** from parent to child,
/// `PreferenceKey` propagates values **up** from child to parent.
///
/// Define a preference by declaring a key type with a default value and a
/// `reduce` function that merges contributions from multiple children:
///
/// ```swift
/// struct MaxHeightPreference: PreferenceKey {
///     static var defaultValue: Int { 0 }
///     static func reduce(value: inout Int, nextValue: () -> Int) {
///         value = Swift.max(value, nextValue())
///     }
/// }
/// ```
///
/// Set the preference on a view with ``View/preference(key:value:)`` and
/// observe it from an ancestor with ``View/onPreferenceChange(_:perform:)``:
///
/// ```swift
/// VStack {
///     Text("short")
///         .preference(key: MaxHeightPreference.self, value: 1)
///     Text("much longer content here")
///         .preference(key: MaxHeightPreference.self, value: 3)
/// }
/// .onPreferenceChange(MaxHeightPreference.self) { maxHeight in
///     // maxHeight == 3 (the maximum of both children's values)
///     self.height = maxHeight
/// }
/// ```
public protocol PreferenceKey {
    /// The type of value this key accumulates.
    associatedtype Value

    /// The value used when no child has set a preference for this key.
    static var defaultValue: Value { get }

    /// Combines an existing accumulated value with a new contribution from a
    /// child view.
    ///
    /// The default implementation for additive keys (e.g. `Int` sum) is:
    ///
    /// ```swift
    /// static func reduce(value: inout Int, nextValue: () -> Int) {
    ///     value += nextValue()
    /// }
    /// ```
    ///
    /// For "first wins" semantics:
    ///
    /// ```swift
    /// static func reduce(value: inout String?, nextValue: () -> String?) {
    ///     value = value ?? nextValue()
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - value: The accumulated value so far; mutate in place to incorporate
    ///     the next child's contribution.
    ///   - nextValue: A closure returning the next child's value; call it at
    ///     most once (it may be expensive to compute).
    static func reduce(value: inout Value, nextValue: () -> Value)
}

// MARK: - PreferenceCollector

/// Thread-local stack that accumulates preference values during the
/// `makeNode()` traversal.
///
/// Values flow upward: child views write via ``write(_:value:)``; ancestor
/// views read via ``capturing(_:)`` after their subtree has rendered.
///
/// Writing pushes into **every** active scope so that nested
/// ``View/onPreferenceChange(_:perform:)`` observers at different tree levels
/// all receive the contributions from their respective subtrees.
enum PreferenceCollector {
    private static let stackKey = "SwiftLI.PreferenceValues.stack"

    private static var stack: [[ObjectIdentifier: Any]] {
        get { Thread.current.threadDictionary[stackKey] as? [[ObjectIdentifier: Any]] ?? [] }
        set { Thread.current.threadDictionary[stackKey] = newValue }
    }

    /// Runs `body` inside a fresh preference scope and returns both its result
    /// and the preference values accumulated by children inside it.
    static func capturing<T>(_ body: () -> T) -> (result: T, values: [ObjectIdentifier: Any]) {
        stack.append([:])
        let result = body()
        let collected = stack.removeLast()
        return (result, collected)
    }

    /// Contributes `value` for `key` into all currently active scopes using
    /// `K.reduce`, so every enclosing observer accumulates it.
    static func write<K: PreferenceKey>(_ key: K.Type, value: K.Value) {
        guard !stack.isEmpty else { return }
        let id = ObjectIdentifier(key)
        for i in stack.indices {
            var accumulated = stack[i][id] as? K.Value ?? K.defaultValue
            K.reduce(value: &accumulated) { value }
            stack[i][id] = accumulated
        }
    }

    /// Reads the innermost scope's current accumulated value for `key`.
    /// Used by ``View/transformPreference(_:_:)`` before applying its transform.
    static func readTop<K: PreferenceKey>(_ key: K.Type) -> K.Value {
        (stack.last?[ObjectIdentifier(key)] as? K.Value) ?? K.defaultValue
    }

    /// Replaces the innermost scope's value for `key` directly.
    /// Used by ``View/transformPreference(_:_:)`` after applying its transform.
    static func setTop<K: PreferenceKey>(_ key: K.Type, _ value: K.Value) {
        guard !stack.isEmpty else { return }
        stack[stack.count - 1][ObjectIdentifier(key)] = value
    }

    /// Reads the value for `key` from a captured scope dictionary returned by
    /// ``capturing(_:)``.
    static func read<K: PreferenceKey>(_ key: K.Type, from values: [ObjectIdentifier: Any]) -> K.Value {
        (values[ObjectIdentifier(key)] as? K.Value) ?? K.defaultValue
    }
}

// MARK: - PreferenceObserverRegistry

/// Tracks the last-seen preference value per observer call site so that
/// ``View/onPreferenceChange(_:perform:)`` only fires `perform` when the
/// value actually changes.
///
/// Without this guard, `perform` would run every render pass; if it updates
/// `@State`, the resulting re-render would fire `perform` again — an infinite
/// loop. Checking for equality breaks the cycle.
final class PreferenceObserverRegistry: @unchecked Sendable {
    static let shared = PreferenceObserverRegistry()

    private let lock = NSLock()
    private var lastValues: [String: Any] = [:]

    private init() {}

    /// Returns `true` and records `newValue` if it differs from the previously
    /// stored value for `id`, or if `id` has never been seen before.
    func hasChanged<V: Equatable>(_ id: String, to newValue: V) -> Bool {
        lock.lock(); defer { lock.unlock() }
        if let old = lastValues[id] as? V, old == newValue { return false }
        lastValues[id] = newValue
        return true
    }

    /// Clears all stored last-values. Called at session teardown so a new
    /// session starts with no remembered state.
    func reset() {
        lock.lock(); lastValues.removeAll(); lock.unlock()
    }
}

// MARK: - .preference(key:value:)

/// The view produced by ``View/preference(key:value:)``: writes `value`
/// into the preference store after its content lowers, then lowers the
/// content unchanged.
struct PreferenceWriter<K: PreferenceKey>: View, @unchecked Sendable {
    let content: any View
    let value: K.Value

    var body: some View { EmptyView() }

    func applyingStyle(_ style: TextStyle) -> Self {
        PreferenceWriter(content: content.applyingStyle(style), value: value)
    }

    func makeNode() -> RenderNode {
        // Lower content first so any deeper preferences accumulate before ours.
        let node = content.makeNode()
        PreferenceCollector.write(K.self, value: value)
        return node
    }
}

// MARK: - .transformPreference(_:_:)

/// The view produced by ``View/transformPreference(_:_:)``: applies a
/// transform to the innermost scope's accumulated value after its content
/// lowers.
struct PreferenceTransformer<K: PreferenceKey>: View, @unchecked Sendable {
    let content: any View
    let transform: (inout K.Value) -> Void

    var body: some View { EmptyView() }

    func applyingStyle(_ style: TextStyle) -> Self {
        PreferenceTransformer(content: content.applyingStyle(style), transform: transform)
    }

    func makeNode() -> RenderNode {
        let node = content.makeNode()
        var value = PreferenceCollector.readTop(K.self)
        transform(&value)
        PreferenceCollector.setTop(K.self, value)
        return node
    }
}

// MARK: - .onPreferenceChange(_:perform:)

/// The view produced by ``View/onPreferenceChange(_:perform:)``: captures
/// preferences from its subtree and calls `perform` (deferred) when the
/// value changes.
struct PreferenceChangeObserver<K: PreferenceKey>: View, @unchecked Sendable where K.Value: Equatable & Sendable {
    let content: any View
    let observerID: String
    let perform: @Sendable (K.Value) -> Void

    var body: some View { EmptyView() }

    func applyingStyle(_ style: TextStyle) -> Self {
        PreferenceChangeObserver(
            content: content.applyingStyle(style),
            observerID: observerID,
            perform: perform
        )
    }

    func makeNode() -> RenderNode {
        let (node, values) = PreferenceCollector.capturing {
            content.makeNode()
        }
        let value = PreferenceCollector.read(K.self, from: values)
        // Only fire when the value actually changes to avoid infinite re-render loops.
        // Defer via async so the perform closure (which often updates @State) does
        // not re-enter the renderer mid-pass.
        if PreferenceObserverRegistry.shared.hasChanged(observerID, to: value) {
            let perform = self.perform
            DispatchQueue.main.async { [value] in perform(value) }
        }
        return node
    }
}

// MARK: - View extensions

public extension View {
    /// Sets a preference value on this view that ancestor views can read,
    /// mirroring SwiftUI's `preference(key:value:)`.
    ///
    /// Each child's contribution is merged into the ancestor's accumulated
    /// value via `K.reduce`. Multiple siblings that set the same key are all
    /// combined:
    ///
    /// ```swift
    /// struct TagsKey: PreferenceKey {
    ///     static var defaultValue: [String] { [] }
    ///     static func reduce(value: inout [String], nextValue: () -> [String]) {
    ///         value += nextValue()
    ///     }
    /// }
    ///
    /// VStack {
    ///     Text("Swift").preference(key: TagsKey.self, value: ["Swift"])
    ///     Text("CLI").preference(key: TagsKey.self, value: ["CLI"])
    /// }
    /// .onPreferenceChange(TagsKey.self) { tags in
    ///     // tags == ["Swift", "CLI"]
    /// }
    /// ```
    func preference<K: PreferenceKey>(key: K.Type, value: K.Value) -> some View {
        PreferenceWriter<K>(content: self, value: value)
    }

    /// Modifies the accumulated preference for `key` in place, mirroring
    /// SwiftUI's `transformPreference(_:_:)`.
    ///
    /// The transform closure receives the value accumulated by children and
    /// may modify it before it reaches ancestor observers:
    ///
    /// ```swift
    /// ChildView()
    ///     .transformPreference(MaxHeightPreference.self) { $0 = max($0, 5) }
    /// ```
    func transformPreference<K: PreferenceKey>(
        _ key: K.Type,
        _ transform: @escaping (inout K.Value) -> Void
    ) -> some View {
        PreferenceTransformer<K>(content: self, transform: transform)
    }

    /// Calls `perform` when a child view's accumulated preference for `key`
    /// changes, mirroring SwiftUI's `onPreferenceChange(_:perform:)`.
    ///
    /// `perform` is called asynchronously (after the render pass completes)
    /// and only when the value actually changes from the previously observed
    /// one — so updating `@State` inside `perform` does not cause an infinite
    /// re-render loop:
    ///
    /// ```swift
    /// struct Editor: FullScreenCommand {
    ///     @State var wordCount = 0
    ///
    ///     var body: some Scene {
    ///         DocumentView()
    ///             .preference(key: WordCountKey.self, value: document.words.count)
    ///             .onPreferenceChange(WordCountKey.self) { count in
    ///                 wordCount = count
    ///             }
    ///         StatusBar(wordCount: wordCount)
    ///     }
    /// }
    /// ```
    ///
    /// The call site's `#fileID`, `#line`, and `#column` are used as the
    /// observer's stable identity across re-renders — the same mechanism
    /// `task` and `onAppear` use.
    func onPreferenceChange<K: PreferenceKey>(
        _ key: K.Type,
        perform: @escaping @Sendable (K.Value) -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> some View where K.Value: Equatable & Sendable {
        PreferenceChangeObserver<K>(
            content: self,
            observerID: "\(fileID):\(line):\(column):\(String(reflecting: K.self))",
            perform: perform
        )
    }
}
