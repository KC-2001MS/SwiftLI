//
//  CommandState.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2024/05/27.
//

import Foundation

/// A property wrapper for mutable command state that provides a `Binding`
/// via the `$` prefix.
///
/// Use `@CommandState` for values in a ``ViewableCommand`` that should drive
/// the `body` view.  Unlike `@Argument`, `@CommandState` is not parsed from
/// the command line — set the initial value in the declaration or in `run()`.
///
/// ```swift
/// struct Example: AsyncParsableCommand, ViewableCommand {
///     @Argument var initialValue: Double   // parsed from CLI
///     @CommandState var progress: Double = 0.0   // drives the view
///
///     mutating func run() async throws {
///         progress = initialValue          // seed from CLI arg
///         startBodyRendering()
///         for _ in 0..<100 {
///             try await Task.sleep(nanoseconds: 50_000_000)
///             progress += 1
///             updateBody()
///         }
///         stopBodyRendering()
///     }
///
///     var body: some View {
///         ProgressBar(min: 0, value: $progress, max: 100, width: 40)
///     }
/// }
/// ```
@propertyWrapper
public struct CommandState<Value: Sendable>: Sendable {
    private let storage: CommandStateStorage<Value>

    public init(wrappedValue: Value) {
        self.storage = CommandStateStorage(value: wrappedValue)
    }

    /// The current value.
    public var wrappedValue: Value {
        get { storage.value }
        nonmutating set { storage.value = newValue }
    }

    /// A `Binding` to the value, accessible via the `$` prefix.
    public var projectedValue: Binding<Value> {
        Binding(
            get: { storage.value },
            set: { storage.value = $0 }
        )
    }
}

// MARK: - Storage

final class CommandStateStorage<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: Value

    init(value: Value) { _value = value }

    var value: Value {
        get { lock.lock(); defer { lock.unlock() }; return _value }
        set { lock.lock(); _value = newValue; lock.unlock() }
    }
}
