//
//  RetainedTree.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/11/06.
//

/// What a rendering session keeps from one frame to the next: the lowered
/// node of every composite view, keyed by the view's identity, the `@State`
/// storage that belongs to each identity, and the layout measurements.
///
/// SwiftLI re-evaluates the whole body on every change, so without this the
/// engine lowered and measured every view again each frame — the cost of a
/// frame grew with the *total* number of rows even when only the scroll
/// offset moved. With it, a frame still lowers every view (that is what
/// evaluates `@State` and registers controls), but:
///
/// - a subtree whose lowered node **equals** the previous frame's is replaced
///   by the previous frame's node *instance*, so its children arrays keep
///   their storage — and ``LayoutMeasureCache``, which keys measurements on
///   that storage, answers from the previous frame instead of measuring
///   again;
/// - a view's `@State` is handed the same storage on every frame, so state
///   declared in a child view persists exactly as in SwiftUI (the storage of
///   a view that leaves the tree is dropped with it).
///
/// ## Identity
///
/// A view's identity is its structural position: a 64-bit hash of its
/// parent's identity, its index among the parent's children, and its type.
/// Containers assign it through ``View/lowered(at:)``; a wrapper with a single
/// child (a modifier, `AnyView`, an environment scope) shares its identity
/// with that child, so wrapping a view in a modifier does not change which
/// storage it gets.
final class RetainedTree {
    struct Entry {
        var node: RenderNode?
        /// `@State` storages by property name — ``StateStorage`` instances,
        /// erased because each has its own value type.
        var state: [String: AnyObject] = [:]
    }

    /// The identity of the root view of a frame.
    static let rootIdentity: UInt64 = 0

    private var previous: [UInt64: Entry] = [:]
    private var current: [UInt64: Entry] = [:]
    /// Measurements that survive across frames; entries not used by a frame
    /// are dropped at its end.
    let layoutCache = LayoutMeasureCache()
    private var terminalSize: TerminalSize?
    /// Whether any identity of the previous frame holds `@State` storage —
    /// when none does, leaves skip the carry-over lookup entirely.
    private var previousHasState = false

    init() {}

    /// Starts a frame: the identities seen by the previous frame become the
    /// ones this frame may reuse. A terminal resize invalidates every
    /// measurement (widths and heights that defaulted to the terminal size
    /// may change).
    func beginPass(terminalSize: TerminalSize) {
        swap(&previous, &current)
        current.removeAll(keepingCapacity: true)
        previousHasState = previous.contains { !$0.value.state.isEmpty }
        if self.terminalSize != terminalSize {
            layoutCache.removeAll()
            self.terminalSize = terminalSize
        }
        layoutCache.beginPass()
    }

    /// Ends a frame, releasing the measurements it did not use.
    func endPass() {
        layoutCache.endPass()
    }

    /// The identity of child `index` of the view with identity `parent`.
    static func identity(parent: UInt64, index: Int, type: Any.Type) -> UInt64 {
        var h = parent &+ 0x9E37_79B9_7F4A_7C15
        h ^= UInt64(bitPattern: Int64(index)) &* 0xBF58_476D_1CE4_E5B9
        h ^= UInt64(UInt(bitPattern: ObjectIdentifier(type)))
        h = (h ^ (h >> 30)) &* 0xBF58_476D_1CE4_E5B9
        h = (h ^ (h >> 27)) &* 0x94D0_49BB_1331_11EB
        return h ^ (h >> 31)
    }

    /// Records `node` as the lowering of the view with `identity` for this
    /// frame and returns the node to use: the previous frame's node when the
    /// two are equal (so its storage is shared), otherwise `node`.
    func reconcile(_ node: RenderNode, at identity: UInt64) -> RenderNode {
        let old = previous[identity]
        var entry = current[identity] ?? Entry()
        if entry.state.isEmpty, let carried = old?.state { entry.state = carried }
        if let oldNode = old?.node, oldNode.isEquivalent(to: node) {
            entry.node = oldNode
        } else {
            entry.node = node
        }
        current[identity] = entry
        return entry.node!
    }

    /// Keeps the `@State` storages of `identity` alive for this frame even
    /// though its node is not recorded (a leaf view does not need
    /// reconciliation, but a state its body did not read this frame must
    /// survive).
    func carryState(at identity: UInt64) {
        guard previousHasState, current[identity] == nil, let carried = previous[identity]?.state, !carried.isEmpty else { return }
        current[identity] = Entry(node: nil, state: carried)
    }

    /// The storage for the `@State` property `name` of the view with
    /// `identity`: the one the previous frame used when there is one, a new
    /// one from `make` otherwise.
    func stateStorage<Value>(at identity: UInt64, name: String, make: () -> StateStorage<Value>) -> StateStorage<Value> {
        if let existing = current[identity]?.state[name] as? StateStorage<Value> { return existing }
        var entry = current[identity] ?? Entry()
        if entry.state.isEmpty, let carried = previous[identity]?.state { entry.state = carried }
        let storage: StateStorage<Value>
        if let kept = entry.state[name] as? StateStorage<Value> {
            storage = kept
        } else {
            storage = make()
            entry.state[name] = storage
        }
        current[identity] = entry
        return storage
    }
}

// MARK: - Lowering with identity

extension View {
    /// Lowers this view as child `index` of the view currently being lowered.
    ///
    /// Containers lower their children through this instead of calling
    /// `makeNode()` directly: it gives the child its identity (see
    /// ``RetainedTree``) for the duration of its lowering and reconciles the
    /// result with the previous frame. Outside a session that retains frames
    /// it is exactly `makeNode()`.
    /// `_flattenedChildren()` for inlinable callers (an SPI requirement can't
    /// be named from inlinable code directly).
    @usableFromInline
    func flattenedChildren() -> [any View] {
        _flattenedChildren()
    }

    @usableFromInline
    func lowered(at index: Int) -> RenderNode {
        guard let pass = RenderPassContext.current, let tree = pass.retained else { return makeNode() }
        let parent = pass.identity
        let identity = RetainedTree.identity(parent: parent, index: index, type: type(of: self))
        pass.identity = identity
        defer { pass.identity = parent }
        let node = makeNode()
        if node.isLeaf {
            tree.carryState(at: identity)
            return node
        }
        return tree.reconcile(node, at: identity)
    }
}

// MARK: - Structural equivalence

extension RenderNode {
    /// Whether the node has no children of its own. Leaves are compared by
    /// their parent and never reconciled individually.
    var isLeaf: Bool {
        switch self {
        case .empty, .raw, .text, .spacer, .divider: return true
        default: return false
        }
    }

    /// `==`, short-circuited on shared storage.
    ///
    /// After a subtree is reconciled its arrays are the previous frame's, so
    /// comparing it again is a pointer comparison instead of a walk. The
    /// result is always identical to `self == other`.
    func isEquivalent(to other: RenderNode) -> Bool {
        switch (self, other) {
        case (.text(let s1, let c1), .text(let s2, let c2)):
            return s1 == s2 && (Self.sameStorage(c1, c2) || c1 == c2)
        case (.group(let a), .group(let b)):
            return Self.equivalentChildren(a, b)
        case (.vstack(let al1, let sp1, let a), .vstack(let al2, let sp2, let b)):
            return al1 == al2 && sp1 == sp2 && Self.equivalentChildren(a, b)
        case (.hstack(let al1, let sp1, let a), .hstack(let al2, let sp2, let b)):
            return al1 == al2 && sp1 == sp2 && Self.equivalentChildren(a, b)
        case (.padding(let i1, let c1), .padding(let i2, let c2)):
            return i1 == i2 && c1.isEquivalent(to: c2)
        case (.frame(let w1, let h1, let fw1, let fh1, let a1, let c1), .frame(let w2, let h2, let fw2, let fh2, let a2, let c2)):
            return w1 == w2 && h1 == h2 && fw1 == fw2 && fh1 == fh2 && a1 == a2 && c1.isEquivalent(to: c2)
        case (.lineLimit(let l1, let c1), .lineLimit(let l2, let c2)):
            return l1 == l2 && c1.isEquivalent(to: c2)
        case (.scroll(let o1, let h1, let b1, let w1, let c1), .scroll(let o2, let h2, let b2, let w2, let c2)):
            return o1 == o2 && h1 == h2 && b1 == b2 && w1 == w2 && c1.isEquivalent(to: c2)
        case (.hscroll(let o1, let e1, let b1, let h1, let c1), .hscroll(let o2, let e2, let b2, let h2, let c2)):
            return o1 == o2 && e1 == e2 && b1 == b2 && h1 == h2 && c1.isEquivalent(to: c2)
        case (.border(let s1, let f1, let b1, let c1), .border(let s2, let f2, let b2, let c2)):
            return s1 == s2 && f1 == f2 && b1 == b2 && c1.isEquivalent(to: c2)
        case (.shadow(let s1, let r1, let x1, let y1, let c1), .shadow(let s2, let r2, let x2, let y2, let c2)):
            return s1 == s2 && r1 == r2 && x1 == x2 && y1 == y2 && c1.isEquivalent(to: c2)
        case (.viewThatFits(let w1, let h1, let a), .viewThatFits(let w2, let h2, let b)):
            return w1 == w2 && h1 == h2 && Self.equivalentChildren(a, b)
        case (.control(let i1, let c1), .control(let i2, let c2)):
            return i1 == i2 && c1.isEquivalent(to: c2)
        case (.background(let s1, let c1), .background(let s2, let c2)):
            return s1 == s2 && c1.isEquivalent(to: c2)
        default:
            // Leaves without arrays (and mismatched cases).
            return self == other
        }
    }

    private static func equivalentChildren(_ a: [RenderNode], _ b: [RenderNode]) -> Bool {
        if sameStorage(a, b) { return true }
        guard a.count == b.count else { return false }
        for i in a.indices where !a[i].isEquivalent(to: b[i]) { return false }
        return true
    }

    /// Whether two arrays share their storage (and so hold the same elements).
    static func sameStorage<T>(_ a: [T], _ b: [T]) -> Bool {
        guard a.count == b.count, !a.isEmpty else { return a.isEmpty && b.isEmpty }
        return a.withUnsafeBufferPointer { pa in
            b.withUnsafeBufferPointer { pb in pa.baseAddress == pb.baseAddress }
        }
    }
}
