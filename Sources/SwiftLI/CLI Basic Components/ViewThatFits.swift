//
//  ViewThatFits.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/09.
//


/// The axis (or axes) ``ViewThatFits`` measures a candidate against.
public enum FitAxis: Sendable {
    /// Fit on width only (the common case in a terminal).
    case horizontal
    /// Fit on height only.
    case vertical
    /// Fit on both width and height.
    case both
}

/// A view that picks the first of its child views that fits the available space.
///
/// List the candidates from most to least expansive. Each is measured at its
/// natural size and, in order, the first that fits the proposed width (and/or
/// the terminal height) is shown; if none fit, the last candidate is used.
/// Mirrors SwiftUI's `ViewThatFits`.
///
/// ```swift
/// ViewThatFits {
///     Text("Full download progress: 42% complete")
///     Text("42% complete")
///     Text("42%")
/// }
/// ```
///
/// - Note: A candidate is tested at its *natural* (unwrapped) size, so a long
///   ``Text`` that would only fit by wrapping counts as not fitting — exactly
///   what lets the shorter alternatives win on a narrow terminal.
public struct ViewThatFits: View {
    let candidates: [any View]
    let checkWidth: Bool
    let checkHeight: Bool

    /// Creates a view that shows the first fitting candidate.
    ///
    /// - Parameters:
    ///   - axis: The axis to measure the fit on. Defaults to ``FitAxis/horizontal``.
    ///   - content: A ``ViewBuilder`` listing the candidates, widest first.
    public init<Content: View>(in axis: FitAxis = .horizontal, @ViewBuilder content: () -> Content) {
        self.candidates = content()._flattenedChildren()
        switch axis {
        case .horizontal: self.checkWidth = true;  self.checkHeight = false
        case .vertical:   self.checkWidth = false; self.checkHeight = true
        case .both:       self.checkWidth = true;  self.checkHeight = true
        }
    }

    /// The body of the view; the actual rendering is performed by ``makeNode()``.
    public var body: some View {
        EmptyView()
    }

    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        .viewThatFits(checkWidth: checkWidth, checkHeight: checkHeight, candidates: candidates.map { $0.makeNode() })
    }
}
