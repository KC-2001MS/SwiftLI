//
//  Slider.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/11.
//

import Foundation

// MARK: - SliderStyle protocol

/// The values passed to ``SliderStyle/makeBody(configuration:)`` when rendering.
public struct SliderStyleConfiguration {
    /// The slider's label view, or `nil` when the slider has no label.
    public let label: AnyView?
    /// The current value, clamped to ``range``.
    public let value: Double
    /// The closed range the value moves in.
    public let range: ClosedRange<Double>
    /// Width of the track in terminal columns (including the thumb).
    public let width: Int
    /// Whether the slider currently has keyboard focus.
    public let isFocused: Bool
    /// The owning slider's identity, so built-in styles can mark the track as
    /// a pointer sub-region (a click on it jumps to the clicked value).
    var _controlID: String? = nil

    /// The value's position in the range as a `0.0 … 1.0` fraction.
    public var fraction: Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return (value - range.lowerBound) / span
    }
}

/// A type that defines the appearance of a ``Slider``.
///
/// Conform to `SliderStyle` and apply it with ``Slider/sliderStyle(_:)`` (or
/// ``View/sliderStyle(_:)`` for a whole subtree). The default style is
/// ``DefaultSliderStyle``.
public protocol SliderStyle: Sendable {
    /// The type of view produced by this style.
    associatedtype Body: View

    /// Returns a view that represents the slider.
    ///
    /// - Parameter configuration: The slider's label, value, range, track
    ///   width, and focus state.
    @ViewBuilder
    func makeBody(configuration: SliderStyleConfiguration) -> Body

    /// The number of columns the style spends on fixed chrome around the
    /// track (a focus marker, value read-out, etc.). Used when the slider is
    /// auto-sized to the available width. Defaults to `0`.
    var reservedColumns: Int { get }
}

public extension SliderStyle {
    /// Styles reserve no chrome columns by default.
    var reservedColumns: Int { 0 }
}

/// The default slider style — a filled track with a round thumb:
///
/// ```
/// > Volume ━━━━━━●──────────
/// ```
///
/// The filled side is green (cyan while focused), the thumb is bold, and the
/// empty side is dim grey. A `>` marker appears while focused, matching the
/// other controls. Equivalent to ``SliderStyle/automatic``.
public struct DefaultSliderStyle: SliderStyle {
    /// Creates a default slider style.
    public init() {}

    /// Reserves the two columns of the `> ` focus marker.
    public var reservedColumns: Int { 2 }

    /// Returns a view that renders the filled track, thumb, and optional focus marker.
    ///
    /// - Parameter configuration: The slider's label, value, range, track width, and focus state.
    public func makeBody(configuration: SliderStyleConfiguration) -> some View {
        let width = Swift.max(1, configuration.width)
        let fraction = Swift.max(0.0, Swift.min(1.0, configuration.fraction))
        // The thumb occupies one cell of the track; the fill grows behind it.
        let thumbIndex = Int((fraction * Double(width - 1)).rounded())
        let filled = thumbIndex
        let empty = width - 1 - thumbIndex
        let fillColor: Color = configuration.isFocused ? .cyan : .green

        // The track is a pointer sub-region: a click on it jumps the value
        // to the clicked column.
        let track = HitRegion(
            controlID: configuration._controlID,
            role: MouseTargetRegistry.trackRole,
            content: HStack(spacing: 0) {
                if filled > 0 {
                    Text(repeating: "━", count: filled).forgroundColor(fillColor)
                }
                Text(content: "●").forgroundColor(fillColor).bold(configuration.isFocused)
                if empty > 0 {
                    Text(repeating: "─", count: empty).forgroundColor(.eight_bit(240))
                }
            }
        )
        return HStack(spacing: 0) {
            if configuration.isFocused { Text(content: "> ").forgroundColor(.cyan) }
            if let label = configuration.label {
                label
                Text(content: " ")
            }
            track
        }
    }
}

public extension SliderStyle where Self == DefaultSliderStyle {
    /// The default slider style: a filled track with a round thumb.
    static var automatic: Self { .init() }
}

// MARK: - AnySliderStyle (type erasure)

/// A type-erased ``SliderStyle`` whose erased result is an ``AnyView`` — a
/// plain composition of views, matching how ``AnyToggleStyle`` works.
struct AnySliderStyle: SliderStyle, @unchecked Sendable {
    private let _makeBody: (SliderStyleConfiguration) -> any View
    let reservedColumns: Int

    init<S: SliderStyle>(_ style: S) {
        self.reservedColumns = style.reservedColumns
        _makeBody = { style.makeBody(configuration: $0) }
    }

    func makeBody(configuration: SliderStyleConfiguration) -> AnyView {
        AnyView(erasing: _makeBody(configuration))
    }
}

// MARK: - Slider

/// A focusable control for selecting a value from a bounded range, bound to a
/// `Binding<Double>`.
///
/// `Slider` mirrors SwiftUI's `Slider`, adapted to the terminal. While a
/// reactive runtime is active and the slider is focused, <kbd>←</kbd>/<kbd>↓</kbd>
/// step the value down and <kbd>→</kbd>/<kbd>↑</kbd> step it up (clamped to
/// the range), <kbd>Home</kbd>/<kbd>End</kbd> jump to the minimum/maximum, and
/// <kbd>Tab</kbd> / <kbd>Shift-Tab</kbd> move focus. Its appearance is chosen
/// by a ``SliderStyle`` — ``DefaultSliderStyle`` by default.
///
/// ```swift
/// @State var volume = 50.0
///
/// var body: some View {
///     Slider("Volume", value: $volume, in: 0...100, step: 5)
/// }
/// // > Volume ━━━━━━━━━●─────────
/// ```
///
/// Without an explicit `step`, one keypress moves the value by 1/20th of the
/// range.
///
/// > Note: Identity is keyed by ``id``, which defaults to the label text.
/// > Give each slider a distinct label, or pass an explicit `id`, when
/// > several share the same label.
public struct Slider: View, @unchecked Sendable {
    let textStyle: TextStyle
    let id: String
    let label: AnyView?
    let value: Binding<Double>
    let range: ClosedRange<Double>
    /// The per-keypress step, or `nil` to derive one from the range.
    let step: Double?
    /// Width of the track in columns. `nil` (the default) auto-sizes to the
    /// available width, minus the style's chrome and the label.
    let width: Int?
    /// The explicitly applied style, or `nil` to resolve from the environment.
    let style: AnySliderStyle?

    /// Creates a slider with a text label.
    ///
    /// A slider is a pure value editor — it has no submit hook. Pair it with a
    /// ``Button`` when a flow needs an explicit confirmation step.
    ///
    /// - Parameters:
    ///   - label: The text shown beside the track; also the default identity.
    ///   - value: The bound value the slider edits.
    ///   - bounds: The closed range of the value. Defaults to `0...1`.
    ///   - step: The distance one keypress moves the value. Defaults to
    ///     1/20th of the range.
    ///   - width: A fixed track width in columns; `nil` auto-sizes.
    ///   - id: An explicit identity; defaults to the label.
    public init(
        _ label: LocalizedStringKey = "",
        value: Binding<Double>,
        in bounds: ClosedRange<Double> = 0...1,
        step: Double? = nil,
        width: Int? = nil,
        id: String? = nil
    ) {
        let resolved = String(localized: label.localizationValue)
        self.textStyle = .plain
        self.id = id ?? (resolved.isEmpty ? "Slider" : resolved)
        self.label = resolved.isEmpty ? nil : AnyView(Text(content: resolved))
        self.value = value
        self.range = bounds
        self.step = step
        self.width = width
        self.style = nil
    }

    /// Creates a slider with a custom label view.
    ///
    /// - Parameters:
    ///   - value: The bound value the slider edits.
    ///   - bounds: The closed range of the value. Defaults to `0...1`.
    ///   - step: The distance one keypress moves the value. Defaults to
    ///     1/20th of the range.
    ///   - width: A fixed track width in columns; `nil` auto-sizes.
    ///   - id: An explicit identity; defaults to `"Slider"` — give each slider
    ///     a distinct `id` when a screen shows more than one.
    ///   - label: A ``ViewBuilder`` producing the slider's label.
    public init<Label: View>(
        value: Binding<Double>,
        in bounds: ClosedRange<Double> = 0...1,
        step: Double? = nil,
        width: Int? = nil,
        id: String = "Slider",
        @ViewBuilder label: () -> Label
    ) {
        self.textStyle = .plain
        self.id = id
        self.label = AnyView(label())
        self.value = value
        self.range = bounds
        self.step = step
        self.width = width
        self.style = nil
    }

    init(textStyle: TextStyle, id: String, label: AnyView?, value: Binding<Double>, range: ClosedRange<Double>, step: Double?, width: Int?, style: AnySliderStyle?) {
        self.textStyle = textStyle
        self.id = id
        self.label = label
        self.value = value
        self.range = range
        self.step = step
        self.width = width
        self.style = style
    }

    /// The rendered content of this slider; always empty because the slider
    /// is drawn by ``makeNode()`` during the rendering pass.
    public var body: some View {
        EmptyView()
    }

    @_spi(RenderingInternals)
    public func applyingStyle(_ style: TextStyle) -> Self {
        Slider(textStyle: textStyle.inheriting(style), id: id, label: label, value: value, range: range, step: step, width: width, style: self.style)
    }

    /// The per-keypress step: the explicit one, else 1/20th of the range.
    private var resolvedStep: Double {
        if let step { return step }
        let span = range.upperBound - range.lowerBound
        return span > 0 ? span / 20 : 1
    }

    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        FocusCoordinator.shared.registerSlider(id: id, value: value, range: range, step: resolvedStep)
        KeyInputRouter.shared.ensureStarted()

        // Nearest wins: instance style, then subtree environment, then default.
        let resolvedStyle = style ?? EnvironmentStack.current.sliderStyle ?? AnySliderStyle(DefaultSliderStyle())

        // Auto-size the track to the columns this slider is allotted, minus
        // the style's chrome and the label, following ``Gauge``.
        let labelReserve = label.map { NodeLayout.measure($0.makeNode()).width + 1 } ?? 0
        let available = EnvironmentStack.current.maxWidth
        let resolvedWidth = width ?? Swift.max(1, available - resolvedStyle.reservedColumns - labelReserve)

        let clamped = Swift.min(Swift.max(value.wrappedValue, range.lowerBound), range.upperBound)
        var configuration = SliderStyleConfiguration(
            label: label,
            value: clamped,
            range: range,
            width: resolvedWidth,
            isFocused: FocusCoordinator.shared.isFocused(id)
        )
        configuration._controlID = id
        let node = resolvedStyle.makeBody(configuration: configuration).makeNode()
        return (textStyle.isPlain ? node : node.applyingStyle(textStyle)).asControl(id: id)
    }

    /// Sets the style used to render this slider.
    /// - Parameter newStyle: A value conforming to ``SliderStyle``.
    public func sliderStyle(_ newStyle: some SliderStyle) -> Self {
        Slider(textStyle: textStyle, id: id, label: label, value: value, range: range, step: step, width: width, style: AnySliderStyle(newStyle))
    }
}
