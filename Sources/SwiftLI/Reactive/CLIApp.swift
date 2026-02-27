//
//  CLIApp.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2024/05/27.
//

/// The entry-point protocol for a reactive SwiftLI application.
///
/// `CLIApp` is analogous to SwiftUI's `App` protocol. Conform your top-level
/// struct to `CLIApp`, declare your `body`, and annotate it with `@main` to
/// make it the program's entry point.
///
/// ## Basic Example
///
/// ```swift
/// import SwiftLI
///
/// @main
/// struct HelloApp: CLIApp {
///     var body: [View] {
///         Text("Hello, SwiftLI!").bold().newLine()
///     }
/// }
/// ```
///
/// ## Reactive Example with @State
///
/// ```swift
/// import SwiftLI
///
/// @main
/// struct CounterApp: CLIApp {
///     @State var count = 0
///     let timer = CLITimer(interval: 1.0)
///
///     var body: [View] {
///         Text("Count: \(count)").newLine()
///
///         if count >= 5 {
///             Text("Reached 5!").forgroundColor(.green).bold().newLine()
///         }
///     }
///
///     init() {
///         timer.start {
///             if count < 10 {
///                 count += 1
///             } else {
///                 timer.stop()
///                 AppRuntime.shared?.stop()
///             }
///         }
///     }
/// }
/// ```
///
/// ## How It Works
///
/// When `@main` calls `main()`:
/// 1. An instance of the conforming type is created via `init()`.
/// 2. An ``AppRuntime`` is created and started.
/// 3. The runtime calls `body` to obtain the initial view tree and renders it.
/// 4. Whenever a `@State` value changes, `body` is re-evaluated and the
///    terminal is refreshed in-place (without visible flicker).
/// 5. The process keeps running until ``AppRuntime/stop()`` is called or
///    the user presses Ctrl+C.
public protocol CLIApp {
    /// Creates the app's initial state.
    ///
    /// Implement `init()` to set up timers or perform any synchronous
    /// initialization. Async or long-running work should be deferred to a
    /// timer or an `onAppear` modifier.
    init()

    /// The content of the app's user interface.
    ///
    /// SwiftLI re-evaluates this property every time a `@State` value changes
    /// and re-renders the terminal output. Use ``ViewBuilder`` syntax to compose
    /// views declaratively, including `if`/`else` conditional rendering.
    @ViewBuilder
    var body: [View] { get }
}

public extension CLIApp {
    /// The application's main entry point.
    ///
    /// `@main` calls this method automatically. It creates an instance of the
    /// conforming type, wraps it in an ``AppRuntime``, and starts the run loop.
    static func main() {
        let app = Self()
        let runtime = AppRuntime(app: app)
        runtime.run()
    }
}
