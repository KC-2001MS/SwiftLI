//
//  ViewableCommand.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2024/05/27.
//

import Foundation

/// A protocol that adds a declarative ``View`` body to an `AsyncParsableCommand`.
///
/// Conform your command to `ViewableCommand` alongside `AsyncParsableCommand`
/// to get automatic in-place rendering of `body` while `run()` executes.
/// Any `@State` property changes automatically redraw the body — you only need
/// to call ``startBodyRendering()`` once and ``stopBodyRendering()`` at the end.
///
/// ## Usage
///
/// ```swift
/// import ArgumentParser
/// import SwiftLI
///
/// @main
/// struct Example: AsyncParsableCommand, ViewableCommand {
///     @State var value: Double = 0
///
///     let min = 0.0
///     let max = 100.0
///
///     mutating func run() async throws {
///         print("Starting...")          // printed once, never erased
///         startBodyRendering()          // draws body; @State changes auto-redraw it
///
///         for _ in 0..<1000 {
///             try await Task.sleep(nanoseconds: 100_000_000)
///             value += 0.1             // triggers automatic body redraw
///         }
///
///         stopBodyRendering()
///         print("Done!")               // printed once, below the body
///     }
///
///     var body: some View {
///         ProgressBar(min: min, value: $value, max: max)
///     }
/// }
/// ```
///
/// ## How it works
///
/// 1. `startBodyRendering()` draws `body` at the current cursor position,
///    records how many lines it occupies, and registers itself as a
///    ``StateObserverRegistry`` observer.
/// 2. Every time a `@State` property in the command changes, the registry
///    fires the callback, which redraws `body` in-place.
/// 3. `stopBodyRendering()` unregisters the observer and moves the cursor
///    past the finalized body so subsequent `print()` calls appear below it.
public protocol ViewableCommand {
    associatedtype Body: View
    /// The view displayed alongside the command's output.
    var body: Body { get }
}

// MARK: - Default rendering helpers

public extension ViewableCommand {

    /// Draws `body` at the current cursor position and starts observing
    /// `@State` changes for automatic in-place redraws.
    ///
    /// Call this once from `run()` when you are ready to display the body
    /// region. After this, mutating any `@State` property automatically
    /// redraws `body` — no manual ``updateBody()`` call is needed.
    func startBodyRendering() {
        let renderer = InlineRendererStore.shared.renderer
        // Initial draw
        renderer.render(body)
        // Register so that future @State changes trigger a redraw automatically
        StateObserverRegistry.shared.register { [renderer] in
            // We need a fresh snapshot of `body` each time.
            // Because `self` is a struct, we capture it by value here.
            // The body property accesses the StateStorage (reference type)
            // directly, so it always reads the latest value.
            renderer.render(self.body)
        }
    }

    /// Redraws `body` in-place manually.
    ///
    /// Usually you do **not** need to call this when using `@State`, since
    /// state changes trigger automatic redraws. Use this only when you need
    /// to force a redraw without a state change (e.g., when a non-`@State`
    /// property changes).
    func updateBody() {
        InlineRendererStore.shared.renderer.render(body)
    }

    /// Unregisters the state observer and moves the cursor past the body.
    ///
    /// Call this once from `run()` after all updates are complete.
    /// Any `print()` calls after this appear below the completed body.
    func stopBodyRendering() {
        StateObserverRegistry.shared.unregister()
        InlineRendererStore.shared.renderer.finalize()
    }
}

// MARK: - Shared renderer store

/// Singleton store that holds the `InlineRenderer` for the current command.
///
/// Using a store avoids adding stored properties to the protocol extension
/// (which Swift does not allow).
final class InlineRendererStore: @unchecked Sendable {
    static let shared = InlineRendererStore()
    let renderer = InlineRenderer()
    private init() {}
}
