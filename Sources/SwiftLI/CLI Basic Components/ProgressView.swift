//
//  ProgressView.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2024/05/27.
//

import Foundation

// MARK: - ProgressSpinner

/// The rotating single-character Braille spinner used by ``ProgressView`` and,
/// as a collapsed fallback, by the built-in ``GaugeStyle``s.
public enum ProgressSpinner {
    /// The Braille frames cycled through as the spinner advances.
    public static let frames: [Character] = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧"]

    /// The spinner glyph for a given phase (any integer; wraps around the frames).
    public static func character(for phase: Int) -> Character {
        let count = frames.count
        let index = ((phase % count) + count) % count
        return frames[index]
    }

    /// The spinner glyph for a given `0…1` fraction (cycles four times end-to-end).
    ///
    /// Used by the ``GaugeStyle`` collapse path, where a fraction is available.
    public static func character(for fraction: Double) -> Character {
        let clamped = Swift.max(0.0, Swift.min(1.0, fraction))
        let index = Int(clamped * Double(frames.count * 4)) % frames.count
        return frames[index]
    }

    /// The collapsed representation: the spinner glyph followed by `label`
    /// (when non-empty). This is the floor of every gauge style's degradation.
    public static func collapsed(for fraction: Double, label: String) -> String {
        let glyph = character(for: fraction)
        return label.isEmpty ? String(glyph) : "\(glyph) \(label)"
    }
}

// MARK: - ProgressViewStyle protocol

/// The values passed to ``ProgressViewStyle/makeBody(configuration:)`` when rendering.
public struct ProgressViewStyleConfiguration {
    /// A label view describing the work in progress. `nil` when the
    /// ``ProgressView`` has no label.
    public let label: AnyView?
    /// The animation phase; each value selects a spinner frame.
    public let phase: Int
}

/// A type that defines the appearance of a ``ProgressView``.
///
/// Conform to `ProgressViewStyle` and apply it with
/// ``ProgressView/progressViewStyle(_:)`` (or ``View/progressViewStyle(_:)``
/// for a whole subtree). The default style is ``DefaultProgressViewStyle``.
public protocol ProgressViewStyle: Sendable {
    /// The type of view produced by this style.
    associatedtype Body: View

    /// Returns a view that represents the progress indicator.
    ///
    /// - Parameter configuration: The current state of the progress view,
    ///   including its label and animation phase.
    @ViewBuilder
    func makeBody(configuration: ProgressViewStyleConfiguration) -> Body
}

/// The default progress view style — a cyan Braille spinner followed by the
/// label. Equivalent to ``ProgressViewStyle/automatic``.
public struct DefaultProgressViewStyle: ProgressViewStyle {
    public init() {}

    public func makeBody(configuration: ProgressViewStyleConfiguration) -> some View {
        HStack(spacing: 1) {
            Text(verbatim: String(ProgressSpinner.character(for: configuration.phase)))
                .forgroundColor(.cyan)
            if let label = configuration.label {
                label.forgroundColor(.cyan)
            }
        }
    }
}

public extension ProgressViewStyle where Self == DefaultProgressViewStyle {
    /// The default progress view style: a cyan spinner followed by the label.
    static var automatic: Self { .init() }
}

// MARK: - AnyProgressViewStyle (type erasure)

/// A type-erased ``ProgressViewStyle`` whose erased result is an ``AnyView`` —
/// a plain composition of views, matching how ``AnyToggleStyle`` works.
struct AnyProgressViewStyle: ProgressViewStyle, @unchecked Sendable {
    private let _makeBody: (ProgressViewStyleConfiguration) -> any View

    init<S: ProgressViewStyle>(_ style: S) {
        _makeBody = { style.makeBody(configuration: $0) }
    }

    func makeBody(configuration: ProgressViewStyleConfiguration) -> AnyView {
        AnyView(erasing: _makeBody(configuration))
    }
}

// MARK: - ProgressView

/// An **indeterminate** activity indicator: a spinning glyph that signals work
/// is in progress without reporting how much is done.
///
/// `ProgressView` answers only "is something happening?" — it has no value,
/// range, or percentage. For a determinate meter that shows a measurable value,
/// use ``Gauge``.
///
/// The spinner frame is chosen by `phase`. Drive the animation by advancing an
/// integer in your run loop and passing it in, so the reactive runtime redraws
/// a new frame each tick:
///
/// ```swift
/// struct Example: InlineCommand {
///     @State var tick = 0
///     mutating func run() async throws {
///         startBodyRendering()
///         while working {
///             try await Task.sleep(nanoseconds: 80_000_000)
///             tick += 1
///         }
///         stopBodyRendering()
///     }
///     var body: some Scene {
///         ProgressView("Loading", phase: tick)
///     }
/// }
/// ```
///
/// A one-shot render (no `phase`) shows the first frame:
///
/// ```swift
/// ProgressView("Loading").render()   // ⠋ Loading
/// ```
public struct ProgressView: View, Sendable {
    /// A text label shown after the spinner glyph. Empty when there is none.
    public let label: String
    /// The animation phase; each value selects a spinner frame.
    public let phase: Int
    /// The explicitly applied style, or `nil` to resolve from the environment.
    let style: AnyProgressViewStyle?

    /// Creates an indeterminate progress indicator.
    ///
    /// - Parameters:
    ///   - label: A localized description shown after the spinner (e.g.
    ///     `"Loading"`). Defaults to no label.
    ///   - phase: The animation phase selecting the spinner frame. Advance it
    ///     over time to animate; defaults to `0` (a static first frame).
    public init(_ label: LocalizedStringKey = "", phase: Int = 0) {
        self.label = String(localized: label.localizationValue)
        self.phase = phase
        self.style = nil
    }

    // Internal init for style-header chaining.
    init(label: String, phase: Int, style: AnyProgressViewStyle? = nil) {
        self.label = label
        self.phase = phase
        self.style = style
    }

    public var body: some View {
        // Nearest wins: instance style, then subtree environment, then default.
        let resolvedStyle = style ?? EnvironmentStack.current.progressViewStyle ?? AnyProgressViewStyle(DefaultProgressViewStyle())
        resolvedStyle.makeBody(configuration: ProgressViewStyleConfiguration(
            label: label.isEmpty ? nil : AnyView(Text(content: label)),
            phase: phase
        ))
    }

    /// Sets the style used to compose this progress view.
    ///
    /// - Parameter newStyle: A value conforming to ``ProgressViewStyle``.
    public func progressViewStyle(_ newStyle: some ProgressViewStyle) -> Self {
        Self(label: label, phase: phase, style: AnyProgressViewStyle(newStyle))
    }
}
