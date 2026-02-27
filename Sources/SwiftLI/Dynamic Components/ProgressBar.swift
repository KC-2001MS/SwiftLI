//
//  ProgressBar.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2024/05/27.
//

import Foundation

/// A horizontal progress bar view.
///
/// `ProgressBar` renders a filled bar representing progress between a minimum
/// and maximum value. It can be used in two ways:
///
/// ## Static / one-shot rendering
///
/// Pass a plain `Double` value to render a snapshot:
///
/// ```swift
/// ProgressBar(value: 0.75, width: 40).newLine().render()
/// // [████████████████████████████████░░░░░░░░] 75%
/// ```
///
/// ## Live updating via Binding (inside ViewableCommand)
///
/// Pass a `Binding<Double>` and the bar redraws in-place whenever the value
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
///         ProgressBar(min: min, value: $value, max: max, width: 40)
///     }
/// }
/// ```
///
/// ## Appearance
///
/// ```
/// [████████████████████░░░░░░░░░░░░░░░░░░░░] 50%
/// ```
///
/// - Filled: `█` (U+2588) in green
/// - Empty:  `░` (U+2591) in grey
public struct ProgressBar: View, Sendable {

    // MARK: - Stored properties

    let header: String

    /// Minimum value (left edge of the bar). Defaults to `0.0`.
    public let min: Double
    /// Maximum value (right edge of the bar). Defaults to `1.0`.
    public let max: Double
    /// Width of the bar in terminal columns. Defaults to `30`.
    public let width: Int
    /// Character for the filled portion. Defaults to `█` (U+2588).
    public let filledCharacter: Character
    /// Character for the empty portion. Defaults to `░` (U+2591).
    public let emptyCharacter: Character

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

    /// Creates a progress bar with a **plain value** (static snapshot).
    ///
    /// - Parameters:
    ///   - min: Minimum value (`0.0` by default).
    ///   - value: Current progress value.
    ///   - max: Maximum value (`1.0` by default).
    ///   - width: Bar width in columns (`30` by default).
    ///   - filledCharacter: Character for the filled segment (`█`).
    ///   - emptyCharacter: Character for the empty segment (`░`).
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
    }

    /// Creates a progress bar driven by a **`Binding`** for live updates.
    ///
    /// When used inside a ``ViewableCommand``, the bar redraws automatically
    /// whenever the bound value changes.
    ///
    /// - Parameters:
    ///   - min: Minimum value (`0.0` by default).
    ///   - value: A `Binding` to the current progress value.
    ///   - max: Maximum value (`1.0` by default).
    ///   - width: Bar width in columns (`30` by default).
    ///   - filledCharacter: Character for the filled segment (`█`).
    ///   - emptyCharacter: Character for the empty segment (`░`).
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
    }

    // Internal init for modifier chaining.
    init(
        header: String,
        min: Double,
        valueSource: ValueSource,
        max: Double,
        width: Int,
        filledCharacter: Character,
        emptyCharacter: Character
    ) {
        self.header = header
        self.min = min
        self.max = max
        self.width = width
        self.filledCharacter = filledCharacter
        self.emptyCharacter = emptyCharacter
        self.valueSource = valueSource
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
            emptyCharacter: emptyCharacter
        )
    }

    public func render() {
        let s = barString(value: valueSource.current)
        print(s, terminator: "")
        fflush(stdout)
    }

    @_spi(RenderingInternals)
    public func renderString() -> String {
        barString(value: valueSource.current)
    }

    @_spi(RenderingInternals)
    public func measure() -> Size {
        let s = barString(value: valueSource.current)
        return _size(of: s.isEmpty ? " " : s)
    }

    @_spi(RenderingInternals)
    public func draw(into canvas: TerminalCanvas, at origin: Point) {
        let s = barString(value: valueSource.current)
        if s.isEmpty { return }
        canvas.expand(toFit: Rect(origin: origin, size: _size(of: s)))
        canvas.write(s, at: origin)
    }

    // MARK: - Internal rendering

    func barString(value: Double) -> String {
        let clamped     = Swift.min(Swift.max(value, min), max)
        let range       = max - min
        let fraction    = range == 0 ? 0 : (clamped - min) / range
        let filledCount = Int(fraction * Double(width))
        let emptyCount  = width - filledCount
        let percentage  = Int(fraction * 100)

        var line = ""
        line += header
        line += "["

        if filledCount > 0 {
            line += "\u{001B}[32m"
            line += String(repeating: filledCharacter, count: filledCount)
            line += "\u{001B}[0m"
        }
        if emptyCount > 0 {
            line += "\u{001B}[38;5;240m"
            line += String(repeating: emptyCharacter, count: emptyCount)
            line += "\u{001B}[0m"
        }

        line += header
        line += "] \(percentage)%"
        line += "\u{001B}[0m"
        return line
    }

    // Legacy name kept for compatibility
    func printBar(value: Double) {
        print(barString(value: value), terminator: "")
        fflush(stdout)
    }

    // MARK: - Modifiers

    /// Applies a foreground color to the brackets and percentage label.
    public func forgroundColor(_ color: Color) -> Self {
        Self(
            header: "\(header)\u{001B}[3\(color.ansi)m",
            min: min, valueSource: valueSource, max: max,
            width: width, filledCharacter: filledCharacter, emptyCharacter: emptyCharacter
        )
    }

    /// Applies a background color behind the bar.
    public func background(_ color: Color) -> Self {
        Self(
            header: "\(header)\u{001B}[4\(color.ansi)m",
            min: min, valueSource: valueSource, max: max,
            width: width, filledCharacter: filledCharacter, emptyCharacter: emptyCharacter
        )
    }
}
