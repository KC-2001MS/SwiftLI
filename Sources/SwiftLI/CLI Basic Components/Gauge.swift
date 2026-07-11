//
//  Gauge.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/09.
//

import Foundation

// MARK: - GaugeStyle protocol

/// A type that defines the appearance of a ``Gauge``.
///
/// Conform to `GaugeStyle` to create a custom gauge style. Use
/// ``Gauge/gaugeStyle(_:)`` to apply a style to a gauge.
///
/// A style is expressed purely as a composition of existing views and
/// modifiers — a ``Gauge`` has no bespoke rendering of its own; it is entirely
/// *derived* from the primitives (``HStack``, ``Text``,
/// ``View/forgroundColor(_:)``) its style returns.
///
/// ## Built-in styles
///
/// - ``BarGaugeStyle`` – renders a filled bar (`[████░░░░] 50%`)
/// - ``LinearGaugeStyle`` – renders a minimal line (`━━━━━━━━━━──────────`)
/// - ``PercentageGaugeStyle`` – renders only the percentage (`50%`)
public protocol GaugeStyle: Sendable {
    /// The type of view produced by this style.
    associatedtype Body: View

    /// Returns a view that represents the gauge.
    ///
    /// - Parameter configuration: The current state of the gauge, including the
    ///   fraction completed and display parameters.
    /// - Returns: A ``View`` that renders the gauge.
    @ViewBuilder
    func makeBody(configuration: GaugeStyleConfiguration) -> Body

    /// The number of columns the style spends on fixed chrome around the
    /// fillable region (brackets, a percentage label, etc.).
    ///
    /// When a ``Gauge`` is auto-sized to the terminal width, this many columns
    /// are subtracted so the whole indicator — chrome included — fits on one
    /// line. Styles that add no chrome can leave the default of `0`.
    var reservedColumns: Int { get }
}

public extension GaugeStyle {
    /// Styles reserve no chrome columns by default.
    var reservedColumns: Int { 0 }
}

/// The values passed to ``GaugeStyle/makeBody(configuration:)`` when rendering.
public struct GaugeStyleConfiguration {
    /// Current progress fraction in the range `0.0 … 1.0`.
    public let fractionCompleted: Double
    /// Width of the gauge in terminal columns.
    public let width: Int
    /// Character used for the filled segment.
    public let filledCharacter: Character
    /// Character used for the empty segment.
    public let emptyCharacter: Character
    /// A label view to show in the trailing status area, where the percentage
    /// is displayed. `nil` when the ``Gauge`` has no label.
    public let label: AnyView?
}

// MARK: - Sub-cell fill

/// Builds a bar fill string with **1/8-cell precision** using the Unicode left
/// block elements (`▏▎▍▌▋▊▉█`), so the bar advances a fraction of a cell at a
/// time instead of jumping a whole column.
///
/// Smoothing only applies to the default full-block fill (`█`); a custom
/// `filled` glyph falls back to whole-cell fill, since eighth blocks only pair
/// cleanly with the full block.
enum GaugeFill {
    /// Left one-eighth … seven-eighths blocks, indexed by the 1…7 remainder.
    static let eighths: [Character] = [" ", "▏", "▎", "▍", "▌", "▋", "▊", "▉"]

    /// Returns `(filled, empty)` — the green fill run (whole blocks plus a
    /// fractional block) and the grey remainder — for `fraction` over `width`.
    static func run(width: Int, fraction: Double, filled: Character, empty: Character) -> (filled: String, empty: String) {
        guard width > 0 else { return ("", "") }
        let clamped = Swift.max(0.0, Swift.min(1.0, fraction))

        if filled == "\u{2588}" {
            // Eighth-precision fill.
            let totalEighths = Int((clamped * Double(width) * 8).rounded())
            let full = Swift.min(width, totalEighths / 8)
            let rem  = totalEighths % 8
            var run = String(repeating: filled, count: full)
            let hasPartial = rem > 0 && full < width
            if hasPartial { run.append(eighths[rem]) }
            let used = full + (hasPartial ? 1 : 0)
            return (run, String(repeating: empty, count: width - used))
        } else {
            // Whole-cell fill for custom glyphs.
            let n = Int(clamped * Double(width))
            return (String(repeating: filled, count: n),
                    String(repeating: empty, count: width - n))
        }
    }
}

// MARK: - BarGaugeStyle

/// A gauge style that renders a bracketed filled bar.
///
/// ```
/// [████████████████████░░░░░░░░░░░░░░░░░░░░] 50%
/// ```
///
/// - Filled portion is rendered in green.
/// - Empty portion is rendered in grey.
public struct BarGaugeStyle: GaugeStyle {
    public init() {}

    /// Reserves `[`, `]`, a space, and up to `100%` (7 columns) around the bar.
    public var reservedColumns: Int { 7 }

    public func makeBody(configuration: GaugeStyleConfiguration) -> some View {
        let fraction   = Swift.max(0.0, Swift.min(1.0, configuration.fractionCompleted))
        let width      = Swift.max(0, configuration.width)
        let percentage = Int(fraction * 100)

        // Sub-cell fill: whole blocks plus a fractional eighth block, so the bar
        // advances smoothly rather than a full column at a time.
        let bar = GaugeFill.run(width: width, fraction: fraction,
                                filled: configuration.filledCharacter,
                                empty: configuration.emptyCharacter)

        // When there is no room for a bar, collapse to a compact spinner glyph
        // plus the label instead of truncating a wide gauge.
        HStack(spacing: 0) {
            if width > 0 {
                Text(verbatim: "[")
                if !bar.filled.isEmpty {
                    Text(verbatim: bar.filled).forgroundColor(.green)
                }
                if !bar.empty.isEmpty {
                    Text(verbatim: bar.empty).forgroundColor(.eight_bit(240))
                }
                Text(verbatim: "] \(percentage)%")
            } else {
                Text(verbatim: String(ProgressSpinner.character(for: fraction)))
            }
            if let label = configuration.label {
                Text(verbatim: " ")
                label
            }
        }
    }
}

// MARK: - LinearGaugeStyle

/// A gauge style that renders a compact horizontal line.
///
/// ```
/// ━━━━━━━━━━━━━━━━━━━━──────────────────────
/// ```
///
/// - Filled portion (`━`) is rendered in green.
/// - Empty portion (`─`) is rendered in grey.
public struct LinearGaugeStyle: GaugeStyle {
    public init() {}

    public func makeBody(configuration: GaugeStyleConfiguration) -> some View {
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
            } else {
                Text(verbatim: String(ProgressSpinner.character(for: fraction)))
            }
            if let label = configuration.label {
                Text(verbatim: " ")
                label
            }
        }
    }
}

// MARK: - PercentageGaugeStyle

/// A gauge style that renders only the percentage value.
///
/// ```
/// 50%
/// ```
///
/// The percentage is rendered in green when at 100%, yellow when above 50%,
/// and the default color otherwise.
public struct PercentageGaugeStyle: GaugeStyle {
    public init() {}

    public func makeBody(configuration: GaugeStyleConfiguration) -> some View {
        let fraction   = Swift.max(0.0, Swift.min(1.0, configuration.fractionCompleted))
        let percentage = Int(fraction * 100)

        HStack(spacing: 0) {
            if percentage == 100 {
                Text(verbatim: "\(percentage)%").forgroundColor(.green)
                if let label = configuration.label {
                    Text(verbatim: " ").forgroundColor(.green)
                    label.forgroundColor(.green)
                }
            } else if percentage >= 50 {
                Text(verbatim: "\(percentage)%").forgroundColor(.yellow)
                if let label = configuration.label {
                    Text(verbatim: " ").forgroundColor(.yellow)
                    label.forgroundColor(.yellow)
                }
            } else {
                Text(verbatim: "\(percentage)%")
                if let label = configuration.label {
                    Text(verbatim: " ")
                    label
                }
            }
        }
    }
}

// MARK: - AnyGaugeStyle (type erasure)

/// A type-erased ``GaugeStyle`` that wraps any concrete style.
///
/// Used internally by ``Gauge`` to store the active style without exposing the
/// associated type. The erased result is an ``AnyView`` — itself a composition
/// of views — so no custom rendering code is involved.
struct AnyGaugeStyle: GaugeStyle, @unchecked Sendable {
    private let _makeBody: (GaugeStyleConfiguration) -> any View
    let reservedColumns: Int

    init<S: GaugeStyle>(_ style: S) {
        self.reservedColumns = style.reservedColumns
        _makeBody = { style.makeBody(configuration: $0) }
    }

    func makeBody(configuration: GaugeStyleConfiguration) -> AnyView {
        AnyView(erasing: _makeBody(configuration))
    }
}

// MARK: - Gauge

/// A horizontal gauge that displays a value within a bounded range.
///
/// `Gauge` renders a determinate meter whose appearance is controlled by a
/// ``GaugeStyle``. The default style is ``BarGaugeStyle``. For an indeterminate
/// "still working" indicator with no measurable value, use ``ProgressView``.
///
/// `Gauge` carries no rendering logic of its own: its ``body`` asks the current
/// style to compose an indicator out of ``HStack``, ``Text``, and the standard
/// style modifiers, and the framework lowers that composition through the shared
/// rendering pipeline like any other view.
///
/// ## Static / one-shot rendering
///
/// ```swift
/// Gauge(value: 0.75, width: 40).render()
/// // [████████████████████████████████░░░░░░░░] 75%
/// ```
///
/// ## Live updating via Binding (inside a command)
///
/// ```swift
/// var body: some View {
///     Gauge(min: 0, value: $value, max: 100, width: 40)
/// }
/// ```
///
/// ## Changing the style
///
/// ```swift
/// Gauge(value: 0.5, width: 40)
///     .gaugeStyle(LinearGaugeStyle())
/// ```
public struct Gauge: View, @unchecked Sendable {

    // MARK: - Stored properties

    /// Minimum value (left edge). Defaults to `0.0`.
    public let min: Double
    /// Maximum value (right edge). Defaults to `1.0`.
    public let max: Double
    /// Width of the fillable region in terminal columns.
    ///
    /// `nil` (the default) auto-sizes to the full terminal width, minus the
    /// active style's ``GaugeStyle/reservedColumns``, and follows the window as
    /// it is resized.
    public let width: Int?
    /// Character for the filled portion. Defaults to `█` (U+2588).
    public let filledCharacter: Character
    /// Character for the empty portion. Defaults to `░` (U+2591).
    public let emptyCharacter: Character
    /// A label view shown in the trailing status area. `nil` when there is none.
    public let label: AnyView?
    /// The explicitly applied style, or `nil` to resolve from the environment.
    let style: AnyGaugeStyle?

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

    /// Creates a gauge with a **plain value** (static snapshot).
    ///
    /// - Parameter label: A localized description shown in the trailing status
    ///   area (e.g. `"Downloading"`). Defaults to no label.
    public init(
        _ label: LocalizedStringKey = "",
        min: Double = 0.0,
        value: Double,
        max: Double = 1.0,
        width: Int? = nil,
        filledCharacter: Character = "\u{2588}",
        emptyCharacter: Character = "\u{2591}"
    ) {
        let resolved = String(localized: label.localizationValue)
        self.label = resolved.isEmpty ? nil : AnyView(Text(content: resolved))
        self.min = min
        self.max = max
        self.width = width
        self.filledCharacter = filledCharacter
        self.emptyCharacter = emptyCharacter
        self.valueSource = .constant(value)
        self.style = nil
    }

    /// Creates a gauge with a **plain value** and a custom label view.
    ///
    /// - Parameter label: A ``ViewBuilder`` producing the label shown in the
    ///   trailing status area.
    public init<Label: View>(
        min: Double = 0.0,
        value: Double,
        max: Double = 1.0,
        width: Int? = nil,
        filledCharacter: Character = "\u{2588}",
        emptyCharacter: Character = "\u{2591}",
        @ViewBuilder label: () -> Label
    ) {
        self.label = AnyView(label())
        self.min = min
        self.max = max
        self.width = width
        self.filledCharacter = filledCharacter
        self.emptyCharacter = emptyCharacter
        self.valueSource = .constant(value)
        self.style = nil
    }

    /// Creates a gauge driven by a **`Binding`** for live updates.
    ///
    /// - Parameter label: A localized description shown in the trailing status
    ///   area (e.g. `"Downloading"`). Defaults to no label.
    public init(
        _ label: LocalizedStringKey = "",
        min: Double = 0.0,
        value: Binding<Double>,
        max: Double = 1.0,
        width: Int? = nil,
        filledCharacter: Character = "\u{2588}",
        emptyCharacter: Character = "\u{2591}"
    ) {
        let resolved = String(localized: label.localizationValue)
        self.label = resolved.isEmpty ? nil : AnyView(Text(content: resolved))
        self.min = min
        self.max = max
        self.width = width
        self.filledCharacter = filledCharacter
        self.emptyCharacter = emptyCharacter
        self.valueSource = .binding(value)
        self.style = nil
    }

    /// Creates a gauge driven by a **`Binding`** with a custom label view.
    ///
    /// - Parameter label: A ``ViewBuilder`` producing the label shown in the
    ///   trailing status area.
    public init<Label: View>(
        min: Double = 0.0,
        value: Binding<Double>,
        max: Double = 1.0,
        width: Int? = nil,
        filledCharacter: Character = "\u{2588}",
        emptyCharacter: Character = "\u{2591}",
        @ViewBuilder label: () -> Label
    ) {
        self.label = AnyView(label())
        self.min = min
        self.max = max
        self.width = width
        self.filledCharacter = filledCharacter
        self.emptyCharacter = emptyCharacter
        self.valueSource = .binding(value)
        self.style = nil
    }

    // Internal init for style chaining.
    init(
        label: AnyView?,
        min: Double,
        valueSource: ValueSource,
        max: Double,
        width: Int?,
        filledCharacter: Character,
        emptyCharacter: Character,
        style: AnyGaugeStyle?
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
    /// The body is recomputed on every access, so a `Binding`-backed gauge
    /// always reflects the latest value when the reactive runtime re-renders.
    public var body: some View {
        let clamped  = Swift.min(Swift.max(valueSource.current, min), max)
        let range    = max - min
        let fraction = range == 0 ? 0 : (clamped - min) / range

        // Nearest wins: instance style, then subtree environment, then default.
        let resolvedStyle = style ?? EnvironmentStack.current.gaugeStyle ?? AnyGaugeStyle(BarGaugeStyle())
        let labelReserve = label.map { NodeLayout.measure($0.makeNode()).width + 1 } ?? 0
        // Auto-size to the columns this gauge is actually allotted: the whole
        // terminal at the top level, or the container's width inside e.g.
        // `.frame(width:)`. Ellipsis truncation would garble a meter, so the
        // gauge shortens its fillable region instead.
        let available = EnvironmentStack.current.maxWidth
        let resolvedWidth = width ?? Swift.max(0, available - resolvedStyle.reservedColumns - labelReserve)

        resolvedStyle.makeBody(configuration: GaugeStyleConfiguration(
            fractionCompleted: fraction,
            width: resolvedWidth,
            filledCharacter: filledCharacter,
            emptyCharacter: emptyCharacter,
            label: label
        ))
    }

    // MARK: - Modifiers

    /// Sets the style used to compose this gauge.
    ///
    /// ```swift
    /// Gauge(value: 0.5, width: 40)
    ///     .gaugeStyle(LinearGaugeStyle())
    /// ```
    ///
    /// - Parameter newStyle: A value conforming to ``GaugeStyle``.
    public func gaugeStyle(_ newStyle: some GaugeStyle) -> Self {
        Self(
            label: label,
            min: min, valueSource: valueSource, max: max,
            width: width, filledCharacter: filledCharacter, emptyCharacter: emptyCharacter,
            style: AnyGaugeStyle(newStyle)
        )
    }
}
