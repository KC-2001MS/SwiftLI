//
//  RenderPass.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/11/06.
//

import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// A per-thread slot holding one reference.
///
/// Backed by a `pthread` key, so a read costs a few nanoseconds — against the
/// few hundred that `Thread.current.threadDictionary` (an `NSMutableDictionary`
/// keyed by a bridged `String`) costs on every access. Both the environment
/// stack and the render-pass context are read for nearly every node of a
/// frame, which made that lookup one of the largest costs of a render. On
/// platforms without `pthread` the slot falls back to the thread dictionary.
final class ThreadLocalSlot<Value: AnyObject>: @unchecked Sendable {
    #if os(Windows)
    private let key = "SwiftLI.ThreadLocalSlot.\(UUID().uuidString)"

    var value: Value? {
        get { Thread.current.threadDictionary[key] as? Value }
        set { Thread.current.threadDictionary[key] = newValue }
    }
    #else
    private var key = pthread_key_t()

    init() {
        // The destructor runs when a thread exits with a value still stored
        // and balances the retain taken when it was stored.
        // The pointer is optional on Glibc and non-optional on Darwin; the
        // cast to an optional reads the same on both.
        pthread_key_create(&key) { pointer in
            if let pointer = pointer as UnsafeMutableRawPointer? {
                Unmanaged<AnyObject>.fromOpaque(pointer).release()
            }
        }
    }

    var value: Value? {
        get {
            guard let pointer = pthread_getspecific(key) else { return nil }
            return Unmanaged<Value>.fromOpaque(pointer).takeUnretainedValue()
        }
        set {
            if let pointer = pthread_getspecific(key) {
                Unmanaged<AnyObject>.fromOpaque(pointer).release()
            }
            if let newValue {
                pthread_setspecific(key, Unmanaged.passRetained(newValue).toOpaque())
            } else {
                pthread_setspecific(key, nil)
            }
        }
    }
    #endif
}

/// Per-thread scratch state that lives for exactly one render pass.
///
/// A pass is bracketed by ``withPass(retaining:_:)`` around the whole
/// *lower → layout → emit* sequence of a renderer (or around a one-shot
/// ``NodeLayout/frame(of:)``). Everything stored here is a pure cache: it
/// never changes what a pass produces, only how much work it repeats.
///
/// - ``terminalSize``: the terminal geometry is queried once per pass (an
///   `ioctl` per call otherwise — and `EnvironmentValues.maxWidth/maxHeight`
///   default to it, so layout used to issue hundreds of syscalls a frame).
/// - ``layoutCache``: memoised container measurements, so the layout engine
///   measures each subtree once instead of once per nesting level. A pass
///   that belongs to a session uses the session's ``RetainedTree`` cache,
///   which carries measurements across frames.
/// - ``retained`` / ``identity``: the session's retained tree and the identity
///   of the view being lowered, for cross-frame reuse of nodes and `@State`.
///
/// The context is thread-local, mirroring ``EnvironmentStack``: a render on
/// the main thread and a one-shot render on a cooperative thread never share
/// state.
final class RenderPassContext {
    var terminalSize: TerminalSize?
    let layoutCache: LayoutMeasureCache
    /// The tree the session keeps between frames, when the pass belongs to one.
    let retained: RetainedTree?
    /// The identity of the view currently being lowered (see ``RetainedTree``).
    var identity: UInt64 = RetainedTree.rootIdentity

    private init(retained: RetainedTree?) {
        self.retained = retained
        self.layoutCache = retained?.layoutCache ?? LayoutMeasureCache()
    }

    private static let slot = ThreadLocalSlot<RenderPassContext>()

    /// The context of the pass in progress on this thread, if any.
    static var current: RenderPassContext? {
        slot.value
    }

    /// Runs `body` inside a render pass. Nested calls join the enclosing pass.
    static func withPass<T>(_ body: () throws -> T) rethrows -> T {
        try withPass(retaining: nil, body)
    }

    /// Runs `body` as one frame of the session that keeps `tree` between
    /// frames. Nested calls join the enclosing pass.
    static func withPass<T>(retaining tree: RetainedTree?, _ body: () throws -> T) rethrows -> T {
        if slot.value != nil { return try body() }
        let context = RenderPassContext(retained: tree)
        slot.value = context
        defer { slot.value = nil }
        if let tree {
            tree.beginPass(terminalSize: TerminalSize.current)
            defer { tree.endPass() }
            return try body()
        }
        return try body()
    }
}

/// Memoises the measured size of container nodes — and the sizes of their
/// children — for the duration of a pass, or across the frames of a session.
///
/// `RenderNode` is a value type, so a subtree has no identity of its own — but
/// a container's `children` array does: its storage buffer. The tree is
/// immutable once lowered, so the same buffer always holds the same children,
/// and the layout engine re-encounters it at every nesting level (a parent's
/// measure, the parent's draw, the node's own draw, a wrapping frame or
/// control…). Keying on the buffer address turns those repeats into lookups.
/// When ``RetainedTree`` hands a frame the previous frame's node for an
/// unchanged subtree, the buffer is the previous frame's too — and so is the
/// measurement.
///
/// Every array with an entry is retained by the cache, so its buffer cannot
/// be freed and its address reused by a *different* array while the entry
/// exists. Entries a pass did not use are dropped at its end.
///
/// A measurement depends on the node and the width proposal. It depends on
/// the ambient `maxWidth` / `maxHeight` environment only when the subtree
/// contains a flexible ``Spacer``, and on the line limit only when a text in
/// the subtree has more visual lines than the limit allows. (The terminal size
/// is fixed per pass, and a session's cache is cleared when it changes.)
/// Neither is part of the key: an entry records what it was measured under
/// together with the subtree's structure — whether it holds a spacer, and the
/// most visual lines any of its texts has — so a spacer-free subtree measured
/// while a `.frame(height:)` scoped the environment, or a subtree of
/// single-line texts measured under a different line limit, is still a hit
/// when the layout engine meets it again.
final class LayoutMeasureCache {
    struct Key: Hashable {
        let buffer: UInt
        let kind: UInt8
        let spacing: Int
        let proposedWidth: Int?
    }

    /// What a measurement's validity depends on: whether the subtree holds a
    /// flexible spacer (so the environment mattered) and the most visual lines
    /// any text in it renders unlimited (so a line limit below that matters).
    struct Structure {
        var dependsOnEnvironment = false
        var maxVisualLines = 0

        static let leaf = Structure()

        mutating func merge(_ other: Structure) {
            dependsOnEnvironment = dependsOnEnvironment || other.dependsOnEnvironment
            maxVisualLines = Swift.max(maxVisualLines, other.maxVisualLines)
        }
    }

    /// A container's size together with the sizes of its (flattened) children,
    /// so drawing it needs one lookup instead of one per child.
    struct Entry {
        let size: Size
        let childSizes: [Size]
        let structure: Structure
        /// For a row whose children overflowed its proposal and were divided
        /// (see `NodeLayout.divideRow`): the width proposed to each child,
        /// `nil` for a child that kept its natural width. `nil` for other
        /// containers and rows that fit.
        var childProposals: [Int?]? = nil
        var lineLimit: Int?
        var maxWidth = 0
        var maxHeight = 0
    }

    private struct Slot {
        var entry: Entry
        /// Retains the measured array so its buffer address stays unique.
        let children: [RenderNode]
        var generation: UInt32
    }

    private struct StructureSlot {
        let structure: Structure
        var generation: UInt32
    }

    private var slots: [Key: Slot] = [:]
    /// The structure of the subtree held by each measured children buffer — a
    /// structural fact, so it is shared across the proposals the container was
    /// measured under.
    private var structures: [UInt: StructureSlot] = [:]
    /// Incremented per pass; entries not touched by the current generation
    /// are dropped at the pass's end.
    private var generation: UInt32 = 0

    static func key(for children: [RenderNode], kind: UInt8, spacing: Int, proposedWidth: Int?) -> Key {
        Key(
            buffer: children.withUnsafeBufferPointer { UInt(bitPattern: $0.baseAddress) },
            kind: kind,
            spacing: spacing,
            proposedWidth: proposedWidth
        )
    }

    /// Starts a pass over a cache that outlives passes.
    func beginPass() {
        generation &+= 1
    }

    /// Ends a pass: measurements it did not use belong to subtrees that are
    /// gone (or changed), so they — and the arrays they retain — are released.
    func endPass() {
        slots = slots.filter { $0.value.generation == generation }
        structures = structures.filter { $0.value.generation == generation }
    }

    func removeAll() {
        slots.removeAll()
        structures.removeAll()
    }

    /// The structure of the container holding `children`, if it was measured
    /// in this session.
    func structure(of children: [RenderNode]) -> Structure? {
        let buffer = children.withUnsafeBufferPointer { UInt(bitPattern: $0.baseAddress) }
        guard let index = structures.index(forKey: buffer) else { return nil }
        structures.values[index].generation = generation
        return structures.values[index].structure
    }

    /// A line limit as the number of lines it actually allows: `nil` and
    /// non-positive limits allow any number.
    private static func allowance(_ lineLimit: Int?) -> Int {
        guard let lineLimit, lineLimit > 0 else { return Int.max }
        return lineLimit
    }

    /// The entry for `key` if it was measured in this session and is valid
    /// under `lineLimit` and the current environment.
    func entry(for key: Key, lineLimit: Int?) -> Entry? {
        guard let index = slots.index(forKey: key) else { return nil }
        let cached = slots.values[index].entry
        if cached.lineLimit != lineLimit {
            // A different limit gives the same result as long as no text in
            // the subtree reaches either limit.
            let lines = cached.structure.maxVisualLines
            guard lines <= Self.allowance(lineLimit), lines <= Self.allowance(cached.lineLimit) else { return nil }
        }
        if cached.structure.dependsOnEnvironment {
            let environment = EnvironmentStack.current
            guard cached.maxWidth == environment.maxWidth, cached.maxHeight == environment.maxHeight else { return nil }
        }
        slots.values[index].generation = generation
        return cached
    }

    func entry(for key: Key, lineLimit: Int?, children: [RenderNode], compute: () -> Entry) -> Entry {
        if let cached = entry(for: key, lineLimit: lineLimit) { return cached }
        var entry = compute()
        entry.lineLimit = lineLimit
        if entry.structure.dependsOnEnvironment {
            let environment = EnvironmentStack.current
            entry.maxWidth = environment.maxWidth
            entry.maxHeight = environment.maxHeight
        }
        slots[key] = Slot(entry: entry, children: children, generation: generation)
        structures[key.buffer] = StructureSlot(structure: entry.structure, generation: generation)
        return entry
    }
}
