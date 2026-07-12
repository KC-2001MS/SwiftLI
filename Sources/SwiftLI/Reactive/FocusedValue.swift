//
//  FocusedValue.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/12.
//

import Foundation

// MARK: - FocusedValueKey

/// A key for a value exposed by views to commands, mirroring SwiftUI's
/// `FocusedValueKey`.
///
/// Define a focused value by declaring a key type, then exposing it as a
/// computed property on ``FocusedValues``:
///
/// ```swift
/// struct SelectedItemKey: FocusedValueKey {
///     typealias Value = Item
/// }
///
/// extension FocusedValues {
///     var selectedItem: SelectedItemKey.Value? {
///         get { self[SelectedItemKey.self] }
///         set { self[SelectedItemKey.self] = newValue }
///     }
/// }
/// ```
///
/// Publish the value from a view with ``View/focusedValue(_:_:)`` and read it
/// in a ``Commands`` body with ``FocusedValue``:
///
/// ```swift
/// // In a view:
/// ItemRow(item: item)
///     .focusedValue(\.selectedItem, item)
///
/// // In a Commands type:
/// struct EditCommands: Commands {
///     @FocusedValue(\.selectedItem) var selectedItem: Item?
///
///     var body: some Commands {
///         CommandMenu("Edit") {
///             Button("Delete") { selectedItem?.delete() }
///                 .disabled(selectedItem == nil)
///         }
///     }
/// }
///
/// // Attach to a scene:
/// struct Editor: FullScreenCommand {
///     var body: some Scene {
///         DocumentView()
///             .commands { EditCommands() }
///     }
/// }
/// ```
public protocol FocusedValueKey {
    /// The non-optional base type of the value. The value is always `Value?`
    /// in ``FocusedValues`` — `nil` when no view is currently publishing it.
    associatedtype Value
}

// MARK: - FocusedValues

/// A collection of values published by views to commands, mirroring SwiftUI's
/// `FocusedValues`.
///
/// Add an entry by conforming to ``FocusedValueKey`` and extending this type:
///
/// ```swift
/// extension FocusedValues {
///     var selectedItem: SelectedItemKey.Value? {
///         get { self[SelectedItemKey.self] }
///         set { self[SelectedItemKey.self] = newValue }
///     }
/// }
/// ```
public struct FocusedValues {
    var storage: [ObjectIdentifier: Any] = [:]

    /// Accesses the value for `keyType`, returning `nil` when no view is
    /// currently publishing it.
    public subscript<K: FocusedValueKey>(_ keyType: K.Type) -> K.Value? {
        get { storage[ObjectIdentifier(keyType)] as? K.Value }
        set { storage[ObjectIdentifier(keyType)] = newValue }
    }
}

// MARK: - FocusedValuesStore

/// The process-wide store of currently published focused values.
///
/// Views write here during `makeNode()` via ``View/focusedValue(_:_:)``;
/// ``FocusedValue`` wrappers in ``Commands`` read from here at body-evaluation
/// time. The store is cleared at the start of each outermost render pass so
/// stale entries from removed views do not persist.
final class FocusedValuesStore: @unchecked Sendable {

    static let shared = FocusedValuesStore()

    private let lock = NSLock()
    private var _values = FocusedValues()

    private init() {}

    /// A snapshot of the currently published values.
    var current: FocusedValues {
        lock.lock(); defer { lock.unlock() }
        return _values
    }

    /// Applies `transform` to the stored values under the lock.
    func update(_ transform: (inout FocusedValues) -> Void) {
        lock.lock()
        transform(&_values)
        lock.unlock()
    }

    /// Clears all published values. Called by ``FocusCoordinator`` at the
    /// start of each outermost render pass so stale entries from views that
    /// were removed do not persist into later passes.
    func clear() {
        lock.lock(); _values = FocusedValues(); lock.unlock()
    }
}

// MARK: - @FocusedValue

/// A property wrapper that reads a value published by a view, mirroring
/// SwiftUI's `@FocusedValue`.
///
/// Use this in a ``Commands`` type to read a value set by
/// ``View/focusedValue(_:_:)`` in the command's content. The value is `nil`
/// when no view is currently publishing it:
///
/// ```swift
/// struct EditCommands: Commands {
///     @FocusedValue(\.selectedDocument) var document: Document?
///
///     var body: some Commands {
///         CommandMenu("File") {
///             Button("Save") { document?.save() }
///                 .disabled(document == nil)
///         }
///     }
/// }
/// ```
///
/// Because commands are re-evaluated every render pass, `wrappedValue` always
/// reflects the value published during the previous pass.
@propertyWrapper
public struct FocusedValue<Value> {
    private let keyPath: KeyPath<FocusedValues, Value?>

    /// Creates the wrapper for the given ``FocusedValues`` key path.
    ///
    /// - Parameter keyPath: A key path to a computed property on
    ///   ``FocusedValues`` declared via ``FocusedValueKey``.
    public init(_ keyPath: KeyPath<FocusedValues, Value?>) {
        self.keyPath = keyPath
    }

    /// The value most recently published by a view, or `nil` when none is
    /// currently publishing it.
    public var wrappedValue: Value? {
        FocusedValuesStore.shared.current[keyPath: keyPath]
    }
}

// MARK: - .focusedValue(_:_:) modifier

/// The view produced by ``View/focusedValue(_:_:)``: writes the given value
/// into ``FocusedValuesStore`` while its content is lowered, then lowers the
/// content unchanged.
struct FocusedValueWriter<Value>: View, @unchecked Sendable {
    let content: any View
    let keyPath: WritableKeyPath<FocusedValues, Value?>
    let value: Value?

    var body: some View { EmptyView() }

    func applyingStyle(_ style: TextStyle) -> Self {
        FocusedValueWriter(content: content.applyingStyle(style), keyPath: keyPath, value: value)
    }

    func makeNode() -> RenderNode {
        FocusedValuesStore.shared.update { $0[keyPath: keyPath] = value }
        return content.makeNode()
    }
}

public extension View {
    /// Publishes `value` to ``Commands`` for the duration of this view's
    /// render, mirroring SwiftUI's `focusedValue(_:_:)`.
    ///
    /// Any ``FocusedValue`` wrapper whose key path matches `keyPath` in a
    /// ``Commands`` body will read `value` on the next render pass:
    ///
    /// ```swift
    /// DocumentView(document: doc)
    ///     .focusedValue(\.selectedDocument, doc)
    /// ```
    ///
    /// Pass `nil` to withdraw the value:
    ///
    /// ```swift
    /// DocumentView(document: doc)
    ///     .focusedValue(\.selectedDocument, isEditing ? doc : nil)
    /// ```
    func focusedValue<Value>(_ keyPath: WritableKeyPath<FocusedValues, Value?>, _ value: Value?) -> some View {
        FocusedValueWriter(content: self, keyPath: keyPath, value: value)
    }
}

// MARK: - @FocusedBinding

/// A property wrapper that exposes a `Binding` published by a focused view,
/// mirroring SwiftUI's `@FocusedBinding`.
///
/// Use this in a ``Commands`` type when you need to both read **and** write the
/// focused view's state. The view publishes a `Binding` via
/// ``View/focusedValue(_:_:)``; the command reads and modifies it through this
/// wrapper:
///
/// ```swift
/// // Key: Value is Binding<Document>
/// struct DocumentBindingKey: FocusedValueKey {
///     typealias Value = Binding<Document>
/// }
///
/// extension FocusedValues {
///     var document: Binding<Document>? {
///         get { self[DocumentBindingKey.self] }
///         set { self[DocumentBindingKey.self] = newValue }
///     }
/// }
///
/// // In a view — pass the $-projected binding:
/// DocumentEditor(document: $document)
///     .focusedValue(\.document, $document)
///
/// // In a Commands type:
/// struct FileCommands: Commands {
///     @FocusedBinding(\.document) var document: Document?
///
///     var body: some Commands {
///         CommandMenu("File") {
///             Button("Save") { document?.save() }
///                 .disabled(document == nil)
///             // $document: Binding<Document>? — for passing to child views
///         }
///     }
/// }
/// ```
///
/// - `wrappedValue` gives the current `Value?` (read/write convenience).
/// - `projectedValue` (`$`-prefix) gives the underlying `Binding<Value>?`.
@propertyWrapper
public struct FocusedBinding<Value: Sendable> {
    private let keyPath: KeyPath<FocusedValues, Binding<Value>?>

    /// Creates the wrapper for the given ``FocusedValues`` key path.
    ///
    /// - Parameter keyPath: A key path to a computed property on
    ///   ``FocusedValues`` whose type is `Binding<Value>?`.
    public init(_ keyPath: KeyPath<FocusedValues, Binding<Value>?>) {
        self.keyPath = keyPath
    }

    /// The current value of the focused binding, or `nil` when no view is
    /// publishing it. Setting this writes through to the binding's setter,
    /// updating the originating view's state.
    public var wrappedValue: Value? {
        get {
            FocusedValuesStore.shared.current[keyPath: keyPath]?.wrappedValue
        }
        nonmutating set {
            guard let newValue else { return }
            // Binding.wrappedValue has a nonmutating setter that calls through
            // to the stored closure, so writing on a copy is safe here.
            FocusedValuesStore.shared.current[keyPath: keyPath]?.wrappedValue = newValue
        }
    }

    /// The focused binding, or `nil` when no view is publishing it.
    ///
    /// Use the `$` prefix to obtain this value:
    ///
    /// ```swift
    /// @FocusedBinding(\.document) var document
    /// // $document : Binding<Document>?
    /// ```
    public var projectedValue: Binding<Value>? {
        FocusedValuesStore.shared.current[keyPath: keyPath]
    }
}
