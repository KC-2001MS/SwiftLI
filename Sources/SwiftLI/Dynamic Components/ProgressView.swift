//
//  ProgressView.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2024/05/27.
//

import Foundation

// MARK: - ProgressViewStyle protocol

/// A type that defines the appearance of a ``ProgressView``.
///
/// Conform to `ProgressViewStyle` to create a custom progress view style.
/// Use ``ProgressView/progressViewStyle(_:)`` to apply a style to a view.
///
/// ## Built-in styles
///
/// - ``BarProgressViewStyle`` – renders a filled bar (`[████░░░░] 50%`)
/// - ``LinearProgressViewStyle`` – renders a minimal line (`━━━━━━━━━━──────────`)
/// - ``PercentageProgressViewStyle`` – renders only the percentage (`50%`)
/// - ``SpinnerProgressViewStyle`` – renders a Braille spinner (`⠹ Loading...`)
public protocol ProgressViewStyle: Sendable {
    /// The type of view produced by this style.
    associatedtype Body: View

    /// Returns a view that represents the progress indicator.
    ///
    /// - Parameter configuration: The current state of the progress view,
    ///   including the fraction completed and display parameters.
    /// - Returns: A ``View`` that renders the progress indicator.
    @ViewBuilder
    func makeBody(configuration: ProgressViewStyleConfiguration) -> Body
}

/// The values passed to ``ProgressViewStyle/makeBody(configuration:)`` when rendering.
public struct ProgressViewStyleConfiguration: Sendable {
    /// Current progress fraction in the range `0.0 … 1.0`.
    public let fractionCompleted: Double
    /// Width of the progress indicator in terminal columns.
    public let width: Int
    /// Character used for the filled segment.
    public let filledCharacter: Character
    /// Character used for the empty segment.
    public let emptyCharacter: Character
}

// MARK: - BarProgressViewStyle

/// A progress view style that renders a bracketed filled bar.
///
/// ```
/// [████████████████████░░░░░░░░░░░░░░░░░░░░] 50%
/// ```
///
/// - Filled portion is rendered in green.
/// - Empty portion is rendered in grey.
public struct BarProgressViewStyle: ProgressViewStyle {
    public init() {}

    public func makeBody(configuration: ProgressViewStyleConfiguration) -> some View {
        let fraction   = Swift.max(0.0, Swift.min(1.0, configuration.fractionCompleted))
        let filled     = Int(fraction * Double(configuration.width))
        let empty      = configuration.width - filled
        let percentage = Int(fraction * 100)

        HStack(spacing: 0) {
            Text(verbatim: "[")
            if filled > 0 {
                Text(repeating: configuration.filledCharacter, count: filled)
                    .forgroundColor(.green)
            }
            if empty > 0 {
                Text(repeating: configuration.emptyCharacter, count: empty)
                    .forgroundColor(.eight_bit(240))
            }
            Text(verbatim: "] \(percentage)%")
        }
    }
}

// MARK: - LinearProgressViewStyle

/// A progress view style that renders a compact horizontal line.
///
/// ```
/// ━━━━━━━━━━━━━━━━━━━━──────────────────────
/// ```
///
/// - Filled portion (`━`) is rendered in green.
/// - Empty portion (`─`) is rendered in grey.
public struct LinearProgressViewStyle: ProgressViewStyle {
    public init() {}

    public func makeBody(configuration: ProgressViewStyleConfiguration) -> some View {
        let fraction = Swift.max(0.0, Swift.min(1.0, configuration.fractionCompleted))
        let filled   = Int(fraction * Double(configuration.width))
        let empty    = configuration.width - filled

        HStack(spacing: 0) {
            if filled > 0 {
                Text(repeating: "━", count: filled)
                    .forgroundColor(.green)
            }
            if empty > 0 {
                Text(repeating: "─", count: empty)
                    .forgroundColor(.eight_bit(240))
            }
        }
    }
}

// MARK: - PercentageProgressViewStyle

/// A progress view style that renders only the percentage value.
///
/// ```
/// 50%
/// ```
///
/// The percentage is rendered in green when at 100%, yellow when above 50%,
/// and the default color otherwise.
public struct PercentageProgressViewStyle: ProgressViewStyle {
    public init() {}

    public func makeBody(configuration: ProgressViewStyleConfiguration) -> some View {
        let fraction   = Swift.max(0.0, Swift.min(1.0, configuration.fractionCompleted))
        let percentage = Int(fraction * 100)

        if percentage == 100 {
            return Text(verbatim: "\(percentage)%").forgroundColor(.green)
        } else if percentage >= 50 {
            return Text(verbatim: "\(percentage)%").forgroundColor(.yellow)
        } else {
            return Text(verbatim: "\(percentage)%")
        }
    }
}

// MARK: - SpinnerProgressViewStyle

/// A progress view style that renders a Braille spinner followed by a label.
///
/// The spinner frame advances with the progress value, cycling through
/// eight Braille patterns. This style is most useful for live-updating views
/// inside a ``ViewableCommand``.
///
/// ```
/// ⠋ Loading...
/// ⠙ Loading...
/// ⠹ Loading...
/// ```
///
/// You can customise the label:
///
/// ```swift
/// ProgressView(value: $progress)
///     .progressViewStyle(SpinnerProgressViewStyle(label: "Processing"))
/// ```
public struct SpinnerProgressViewStyle: ProgressViewStyle {
    /// The frames cycled through as progress advances.
    private static let frames: [Character] = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧"]

    /// The text shown after the spinner character.
    public let label: String

    /// Creates a spinner style with a custom label.
    ///
    /// - Parameter label: The text displayed after the spinner. Defaults to `"Loading"`.
    public init(label: String = "Loading") {
        self.label = label
    }

    public func makeBody(configuration: ProgressViewStyleConfiguration) -> some View {
        let fraction   = Swift.max(0.0, Swift.min(1.0, configuration.fractionCompleted))
        let frameCount = Self.frames.count
        let index      = Int(fraction * Double(frameCount * 4)) % frameCount
        let frame      = Self.frames[index]
        return Text(verbatim: "\(frame) \(label)...").forgroundColor(.cyan)
    }
}

// MARK: - AnyProgressViewStyle (type erasure)

/// A type-erased ``ProgressViewStyle`` that wraps any concrete style.
///
/// Used internally by ``ProgressView`` to store the active style without
/// exposing the associated type.
struct AnyProgressViewStyle: ProgressViewStyle, @unchecked Sendable {
    private let _makeBody: (ProgressViewStyleConfiguration) -> Group

    init<S: ProgressViewStyle>(_ style: S) {
        _makeBody = { config in
            // @ViewBuilder で Body が Group に推論されるため、
            // Group でラップして型消去する。
            let result = style.makeBody(configuration: config)
            if let group = result as? Group {
                return group
            }
            return Group(contents: [result])
        }
    }

    func makeBody(configuration: ProgressViewStyleConfiguration) -> Group {
        _makeBody(configuration)
    }
}



// MARK: - ProgressView

/// A horizontal progress view.
///
/// `ProgressView` renders a progress indicator whose appearance is controlled
/// by a ``ProgressViewStyle``. The default style is ``BarProgressViewStyle``.
///
/// ## Static / one-shot rendering
///
/// Pass a plain `Double` value to render a snapshot:
///
/// ```swift
/// ProgressView(value: 0.75, width: 40).render()
/// // [████████████████████████████████░░░░░░░░] 75%
/// ```
///
/// ## Live updating via Binding (inside ViewableCommand)
///
/// Pass a `Binding<Double>` and the view redraws in-place whenever the value
/// changes — no explicit `render()` calls needed:
///
/// ```swift
/// struct Example: AsyncParsableCommand, ViewableCommand {
///     @Argument var value: Double = 0
///     var min = 0.0; var max = 100.0
///
///     mutating func run() async throws {
///         for _ in 0..<100 {
///             try await Task.sleep(nanoseconds: 50_000_000)
///             value += 1
///         }
///     }
///
///     var body: some View {
///         ProgressView(min: min, value: $value, max: max, width: 40)
///     }
/// }
/// ```
///
/// ## Changing the style
///
/// ```swift
/// ProgressView(value: 0.5, width: 40)
///     .progressViewStyle(LinearProgressViewStyle())
/// ```
public struct ProgressView: View, Sendable {

    // MARK: - Stored properties

    let header: String

    /// Minimum value (left edge). Defaults to `0.0`.
    public let min: Double
    /// Maximum value (right edge). Defaults to `1.0`.
    public let max: Double
    /// Width of the indicator in terminal columns. Defaults to `30`.
    public let width: Int
    /// Character for the filled portion. Defaults to `█` (U+2588).
    public let filledCharacter: Character
    /// Character for the empty portion. Defaults to `░` (U+2591).
    public let emptyCharacter: Character
    /// The type-erased style used to render this progress view.
    let style: AnyProgressViewStyle

    // The current value — stored either as a plain Double or as a Binding.
    private let valueSource: ValueSource

    enum ValueSource: @unchecked Sendable {
        case constant(Double)
        case binding(Binding<Double>)

        var current: Double {
            switch self {
            case .constant(let v): return v
            case .binding(let b): return b.wrappedValue
            }
        }
    }

    // MARK: - Public initialisers

    /// Creates a progress view with a **plain value** (static snapshot).
    public init(
        min: Double = 0.0,
        value: Double,
        max: Double = 1.0,
        width: Int = 30,
        filledCharacter: Character = "\u{2588}",
        emptyCharacter: Character = "\u{2591}"
    ) {
        self.header = ""
        self.min = min
        self.max = max
        self.width = width
        self.filledCharacter = filledCharacter
        self.emptyCharacter = emptyCharacter
        self.valueSource = .constant(value)
        self.style = AnyProgressViewStyle(BarProgressViewStyle())
    }

    /// Creates a progress view driven by a **`Binding`** for live updates.
    public init(
        min: Double = 0.0,
        value: Binding<Double>,
        max: Double = 1.0,
        width: Int = 30,
        filledCharacter: Character = "\u{2588}",
        emptyCharacter: Character = "\u{2591}"
    ) {
        self.header = ""
        self.min = min
        self.max = max
        self.width = width
        self.filledCharacter = filledCharacter
        self.emptyCharacter = emptyCharacter
        self.valueSource = .binding(value)
        self.style = AnyProgressViewStyle(BarProgressViewStyle())
    }

    // Internal init for modifier chaining.
    init(
        header: String,
        min: Double,
        valueSource: ValueSource,
        max: Double,
        width: Int,
        filledCharacter: Character,
        emptyCharacter: Character,
        style: AnyProgressViewStyle
    ) {
        self.header = header
        self.min = min
        self.max = max
        self.width = width
        self.filledCharacter = filledCharacter
        self.emptyCharacter = emptyCharacter
        self.valueSource = valueSource
        self.style = style
    }

    // MARK: - View

    public var body: some View {
        Group(contents: [])
    }

    @_spi(RenderingInternals)
    public func addHeader(_ newHeader: String) -> Self {
        Self(
            header: newHeader + header,
            min: min,
            valueSource: valueSource,
            max: max,
            width: width,
            filledCharacter: filledCharacter,
            emptyCharacter: emptyCharacter,
            style: style
        )
    }

    public func render() {
        styleView(for: valueSource.current).render()
    }

    @_spi(RenderingInternals)
    public func renderString() -> String {
        styleView(for: valueSource.current).renderString()
    }

    @_spi(RenderingInternals)
    public func measure() -> Size {
        styleView(for: valueSource.current).measure()
    }

    @_spi(RenderingInternals)
    public func draw(into canvas: TerminalCanvas, at origin: Point) {
        styleView(for: valueSource.current).draw(into: canvas, at: origin)
    }

    // MARK: - Internal

    /// Builds the styled view for the given raw value.
    private func styleView(for value: Double) -> Group {
        let clamped  = Swift.min(Swift.max(value, min), max)
        let range    = max - min
        let fraction = range == 0 ? 0 : (clamped - min) / range

        let config = ProgressViewStyleConfiguration(
            fractionCompleted: fraction,
            width: width,
            filledCharacter: filledCharacter,
            emptyCharacter: emptyCharacter
        )
        let styledView = style.makeBody(configuration: config)
        return header.isEmpty ? styledView : styledView.addHeader(header)
    }

    // MARK: - Modifiers

    /// Applies a foreground color to the progress indicator.
    public func forgroundColor(_ color: Color) -> Self {
        Self(
            header: "\(header)\u{001B}[3\(color.ansi)m",
            min: min, valueSource: valueSource, max: max,
            width: width, filledCharacter: filledCharacter, emptyCharacter: emptyCharacter,
            style: style
        )
    }

    /// Fills the background behind the progress indicator.
    public func background(_ color: Color) -> Self {
        Self(
            header: "\(header)\u{001B}[4\(color.ansi)m",
            min: min, valueSource: valueSource, max: max,
            width: width, filledCharacter: filledCharacter, emptyCharacter: emptyCharacter,
            style: style
        )
    }

    /// Sets the style used to render this progress view.
    ///
    /// ```swift
    /// ProgressView(value: 0.5, width: 40)
    ///     .progressViewStyle(LinearProgressViewStyle())
    /// ```
    ///
    /// - Parameter style: A value conforming to ``ProgressViewStyle``.
    public func progressViewStyle(_ newStyle: some ProgressViewStyle) -> Self {
        Self(
            header: header,
            min: min, valueSource: valueSource, max: max,
            width: width, filledCharacter: filledCharacter, emptyCharacter: emptyCharacter,
            style: AnyProgressViewStyle(newStyle)
        )
    }
}

/// Deprecated alias kept for source compatibility.
@available(*, deprecated, renamed: "ProgressView")
public typealias ProgressBar = ProgressView
