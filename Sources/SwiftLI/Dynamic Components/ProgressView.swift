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
/// A style is expressed purely as a composition of existing views and
/// modifiers — a ``ProgressView`` has no bespoke rendering of its own; it is
/// entirely *derived* from the primitives (``HStack``, ``Text``,
/// ``View/forgroundColor(_:)``) its style returns.
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

    /// The number of columns the style spends on fixed chrome around the
    /// fillable region (brackets, a percentage label, etc.).
    ///
    /// When a ``ProgressView`` is auto-sized to the terminal width, this many
    /// columns are subtracted so the whole indicator — chrome included — fits
    /// on one line. Styles that add no chrome can leave the default of `0`.
    var reservedColumns: Int { get }
}

public extension ProgressViewStyle {
    /// Styles reserve no chrome columns by default.
    var reservedColumns: Int { 0 }
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
    /// A text label to show in the trailing status area, where the percentage
    /// is displayed. Empty when the ``ProgressView`` has no label.
    public let label: String
}

// MARK: - ProgressSpinner

/// The rotating single-character spinner shared by the built-in styles.
///
/// A style uses it as its most compact form: when there is no room for a gauge,
/// it collapses to one spinning glyph plus the label. The frame advances with
/// the progress fraction, so it animates as the value moves.
public enum ProgressSpinner {
    /// The Braille frames cycled through as progress advances.
    public static let frames: [Character] = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧"]

    /// The spinner glyph for a given `0…1` fraction (cycles four times end-to-end).
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

    /// Reserves `[`, `]`, a space, and up to `100%` (7 columns) around the bar.
    public var reservedColumns: Int { 7 }

    public func makeBody(configuration: ProgressViewStyleConfiguration) -> some View {
        let fraction   = Swift.max(0.0, Swift.min(1.0, configuration.fractionCompleted))
        let width      = Swift.max(0, configuration.width)
        let filled     = Int(fraction * Double(width))
        let empty      = width - filled
        let percentage = Int(fraction * 100)
        let suffix     = configuration.label.isEmpty ? "" : " \(configuration.label)"

        // When there is no room for a bar, collapse to the style's most compact
        // form — a rotating spinner glyph plus the label — instead of
        // truncating a wide gauge.
        HStack(spacing: 0) {
            if width > 0 {
                Text(verbatim: "[")
                if filled > 0 {
                    Text(repeating: configuration.filledCharacter, count: filled)
                        .forgroundColor(.green)
                }
                if empty > 0 {
                    Text(repeating: configuration.emptyCharacter, count: empty)
                        .forgroundColor(.eight_bit(240))
                }
                Text(verbatim: "] \(percentage)%\(suffix)")
            } else {
                Text(verbatim: ProgressSpinner.collapsed(for: fraction, label: configuration.label))
            }
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
        let width    = Swift.max(0, configuration.width)
        let filled   = Int(fraction * Double(width))
        let empty    = width - filled

        HStack(spacing: 0) {
            if width > 0 {
                if filled > 0 {
                    Text(repeating: "━", count: filled)
                        .forgroundColor(.green)
                }
                if empty > 0 {
                    Text(repeating: "─", count: empty)
                        .forgroundColor(.eight_bit(240))
                }
                if !configuration.label.isEmpty {
                    Text(verbatim: " \(configuration.label)")
                }
            } else {
                // No room for the line → collapse to the spinner + label.
                Text(verbatim: ProgressSpinner.collapsed(for: fraction, label: configuration.label))
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
        let suffix     = configuration.label.isEmpty ? "" : " \(configuration.label)"

        if percentage == 100 {
            return Text(verbatim: "\(percentage)%\(suffix)").forgroundColor(.green)
        } else if percentage >= 50 {
            return Text(verbatim: "\(percentage)%\(suffix)").forgroundColor(.yellow)
        } else {
            return Text(verbatim: "\(percentage)%\(suffix)")
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
    /// The text shown after the spinner character.
    public let label: String

    /// Creates a spinner style with a custom label.
    ///
    /// - Parameter label: The text displayed after the spinner. Defaults to `"Loading"`.
    public init(label: String = "Loading") {
        self.label = label
    }

    public func makeBody(configuration: ProgressViewStyleConfiguration) -> some View {
        let fraction = Swift.max(0.0, Swift.min(1.0, configuration.fractionCompleted))
        let glyph    = ProgressSpinner.character(for: fraction)
        // The ProgressView's own label takes precedence over the style's default.
        let text     = configuration.label.isEmpty ? label : configuration.label
        return Text(verbatim: "\(glyph) \(text)...").forgroundColor(.cyan)
    }
}

// MARK: - AnyProgressViewStyle (type erasure)

/// A type-erased ``ProgressViewStyle`` that wraps any concrete style.
///
/// Used internally by ``ProgressView`` to store the active style without
/// exposing the associated type. The erased result is a ``Group`` — itself a
/// composition of views — so no custom rendering code is involved.
struct AnyProgressViewStyle: ProgressViewStyle, @unchecked Sendable {
    private let _makeBody: (ProgressViewStyleConfiguration) -> Group
    let reservedColumns: Int

    init<S: ProgressViewStyle>(_ style: S) {
        self.reservedColumns = style.reservedColumns
        _makeBody = { config in
            // @ViewBuilder infers Body as Group for the built-in styles; wrap
            // anything else so the erased result is always a Group.
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
/// `ProgressView` carries no rendering logic of its own: its ``body`` simply
/// asks the current style to compose an indicator out of ``HStack``, ``Text``,
/// and the standard style modifiers, and the framework lowers that composition
/// through the shared rendering pipeline like any other view.
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

    /// Minimum value (left edge). Defaults to `0.0`.
    public let min: Double
    /// Maximum value (right edge). Defaults to `1.0`.
    public let max: Double
    /// Width of the fillable region in terminal columns.
    ///
    /// `nil` (the default) auto-sizes to the full terminal width, minus the
    /// active style's ``ProgressViewStyle/reservedColumns``, and follows the
    /// window as it is resized.
    public let width: Int?
    /// Character for the filled portion. Defaults to `█` (U+2588).
    public let filledCharacter: Character
    /// Character for the empty portion. Defaults to `░` (U+2591).
    public let emptyCharacter: Character
    /// A text label shown before the indicator. Empty when there is no label.
    public let label: String
    /// The type-erased style used to compose this progress view.
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
    ///
    /// - Parameter label: A localized description shown before the indicator
    ///   (e.g. `"Downloading"`). Defaults to no label.
    public init(
        _ label: LocalizedStringKey = "",
        min: Double = 0.0,
        value: Double,
        max: Double = 1.0,
        width: Int? = nil,
        filledCharacter: Character = "\u{2588}",
        emptyCharacter: Character = "\u{2591}"
    ) {
        self.label = String(localized: label.localizationValue)
        self.min = min
        self.max = max
        self.width = width
        self.filledCharacter = filledCharacter
        self.emptyCharacter = emptyCharacter
        self.valueSource = .constant(value)
        self.style = AnyProgressViewStyle(BarProgressViewStyle())
    }

    /// Creates a progress view driven by a **`Binding`** for live updates.
    ///
    /// - Parameter label: A localized description shown before the indicator
    ///   (e.g. `"Downloading"`). Defaults to no label.
    public init(
        _ label: LocalizedStringKey = "",
        min: Double = 0.0,
        value: Binding<Double>,
        max: Double = 1.0,
        width: Int? = nil,
        filledCharacter: Character = "\u{2588}",
        emptyCharacter: Character = "\u{2591}"
    ) {
        self.label = String(localized: label.localizationValue)
        self.min = min
        self.max = max
        self.width = width
        self.filledCharacter = filledCharacter
        self.emptyCharacter = emptyCharacter
        self.valueSource = .binding(value)
        self.style = AnyProgressViewStyle(BarProgressViewStyle())
    }

    // Internal init for style chaining.
    init(
        label: String,
        min: Double,
        valueSource: ValueSource,
        max: Double,
        width: Int?,
        filledCharacter: Character,
        emptyCharacter: Character,
        style: AnyProgressViewStyle
    ) {
        self.label = label
        self.min = min
        self.max = max
        self.width = width
        self.filledCharacter = filledCharacter
        self.emptyCharacter = emptyCharacter
        self.valueSource = valueSource
        self.style = style
    }

    // MARK: - View

    /// The composed indicator for the current value.
    ///
    /// The body is recomputed on every access, so a `Binding`-backed progress
    /// view always reflects the latest value when the reactive runtime
    /// re-renders. Everything below this point — measuring, laying out, and
    /// diffing — is handled by the shared pipeline via the default `View`
    /// conformance, exactly as it is for any composite view.
    public var body: some View {
        let clamped  = Swift.min(Swift.max(valueSource.current, min), max)
        let range    = max - min
        let fraction = range == 0 ? 0 : (clamped - min) / range

        // Columns the trailing label (plus one spacing column) consumes when
        // auto-sizing, so the label sits where the percentage does and the
        // whole line still fits the terminal.
        let labelReserve = label.isEmpty ? 0 : TextMetrics.visibleWidth(label) + 1

        // An unspecified width auto-sizes to the terminal, leaving room for the
        // style's chrome and the label so the whole line fits. It may reach 0 on
        // a very narrow terminal, at which point the style drops the gauge and
        // keeps just the percentage/label.
        let resolvedWidth = width ?? Swift.max(0, TerminalSize.current.columns - style.reservedColumns - labelReserve)

        return style.makeBody(configuration: ProgressViewStyleConfiguration(
            fractionCompleted: fraction,
            width: resolvedWidth,
            filledCharacter: filledCharacter,
            emptyCharacter: emptyCharacter,
            label: label
        ))
    }

    // MARK: - Modifiers

    /// Sets the style used to compose this progress view.
    ///
    /// ```swift
    /// ProgressView(value: 0.5, width: 40)
    ///     .progressViewStyle(LinearProgressViewStyle())
    /// ```
    ///
    /// - Parameter style: A value conforming to ``ProgressViewStyle``.
    public func progressViewStyle(_ newStyle: some ProgressViewStyle) -> Self {
        Self(
            label: label,
            min: min, valueSource: valueSource, max: max,
            width: width, filledCharacter: filledCharacter, emptyCharacter: emptyCharacter,
            style: AnyProgressViewStyle(newStyle)
        )
    }
}

/// Deprecated alias kept for source compatibility.
@available(*, deprecated, renamed: "ProgressView")
public typealias ProgressBar = ProgressView
