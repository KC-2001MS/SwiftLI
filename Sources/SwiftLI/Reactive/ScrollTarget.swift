//
//  ScrollTarget.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/11/08.
//

import Foundation

/// Tracks the `scrollTo(_:anchor:)` requests made through a
/// ``ScrollViewProxy`` until the scroll views inside the reader honour them.
final class ScrollTargetRegistry: @unchecked Sendable {
    static let shared = ScrollTargetRegistry()

    /// A pending request: the target's id and where to place it.
    struct Request {
        let target: AnyHashable
        let anchor: UnitPoint?
    }

    private let lock = NSLock()
    private var requests: [String: Request] = [:]

    private init() {}

    /// The id of the marker node that wraps the view given `.id(id)`.
    static func markerID(for id: AnyHashable) -> String {
        "swiftli.scrollTarget:\(id.hashValue):\(String(describing: id.base))"
    }

    /// Records a request for the reader `reader`.
    func request(reader: String, target: AnyHashable, anchor: UnitPoint?) {
        lock.lock(); requests[reader] = Request(target: target, anchor: anchor); lock.unlock()
    }

    /// Takes the pending request for `reader`, if any.
    func take(reader: String) -> Request? {
        lock.lock(); defer { lock.unlock() }
        return requests.removeValue(forKey: reader)
    }

    func reset() {
        lock.lock(); requests.removeAll(); lock.unlock()
    }
}

/// A normalized point in a view's bounds, mirroring SwiftUI's `UnitPoint`.
/// ``ScrollViewProxy/scrollTo(_:anchor:)`` uses its vertical component.
public struct UnitPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static let top = UnitPoint(x: 0.5, y: 0)
    public static let center = UnitPoint(x: 0.5, y: 0.5)
    public static let bottom = UnitPoint(x: 0.5, y: 1)
    public static let leading = UnitPoint(x: 0, y: 0.5)
    public static let trailing = UnitPoint(x: 1, y: 0.5)
    public static let topLeading = UnitPoint(x: 0, y: 0)
    public static let topTrailing = UnitPoint(x: 1, y: 0)
    public static let bottomLeading = UnitPoint(x: 0, y: 1)
    public static let bottomTrailing = UnitPoint(x: 1, y: 1)
}

// MARK: - ScrollViewReader

private struct ScrollReaderIDKey: EnvironmentKey {
    static var defaultValue: String? { nil }
}

extension EnvironmentValues {
    /// The enclosing ``ScrollViewReader``, whose proxy's requests the scroll
    /// views inside honour.
    var scrollReaderID: String? {
        get { self[ScrollReaderIDKey.self] }
        set { self[ScrollReaderIDKey.self] = newValue }
    }
}

/// A handle for scrolling the ``ScrollView``s inside a ``ScrollViewReader``
/// to a view given `.id(_:)`, mirroring SwiftUI's `ScrollViewProxy`.
public struct ScrollViewProxy: Sendable {
    let reader: String

    /// Scrolls the scroll views inside the reader so the view tagged with
    /// `id` is visible, placed at `anchor` (its vertical component: `.top`
    /// aligns the view's first row with the viewport's top, `.center`
    /// centres it, `.bottom` aligns its last row with the bottom). `nil`
    /// places it at the top.
    public func scrollTo<ID: Hashable>(_ id: ID, anchor: UnitPoint? = nil) {
        ScrollTargetRegistry.shared.request(reader: reader, target: AnyHashable(id), anchor: anchor)
        // The request is honoured by the next frame.
        AppRuntime.shared?.scheduleRender()
        StateObserverRegistry.shared.notifyChange()
    }
}

/// Gives its content a ``ScrollViewProxy`` for programmatic scrolling,
/// mirroring SwiftUI's `ScrollViewReader`.
///
/// ```swift
/// ScrollViewReader { proxy in
///     ScrollView {
///         ForEach(lines) { line in Text(line.text).id(line.id) }
///     }
///     .onKeyPress("G") { proxy.scrollTo(lines.last?.id, anchor: .bottom); return .handled }
/// }
/// ```
public struct ScrollViewReader<Content: View>: View {
    let reader: String
    let content: (ScrollViewProxy) -> Content

    /// Creates a reader; each call site is its own reader.
    public init(fileID: String = #fileID, line: Int = #line, column: Int = #column, @ViewBuilder content: @escaping (ScrollViewProxy) -> Content) {
        self.reader = "\(fileID):\(line):\(column)"
        self.content = content
    }

    public var body: some View {
        content(ScrollViewProxy(reader: reader))
            .environment(\.scrollReaderID, reader)
    }
}
