//
//  ScrollIndicators.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/11/07.
//

/// The visibility of scroll indicators, mirroring SwiftUI's
/// `ScrollIndicatorVisibility`.
///
/// Apply it with ``View/scrollIndicators(_:axes:)``:
///
/// ```swift
/// ScrollView {
///     ForEach(0..<100) { i in Text("Row \(i)") }
/// }
/// .scrollIndicators(.hidden)
/// ```
///
/// A terminal has no overlay scrollbars that fade in on demand, so
/// ``automatic`` and ``visible`` both draw the bar, and ``hidden`` and
/// ``never`` both leave it out. Scrolling with the keyboard and wheel works
/// either way.
public struct ScrollIndicatorVisibility: Equatable, Sendable {
    private enum Storage: Equatable, Sendable {
        case automatic, visible, hidden, never
    }

    private let storage: Storage

    private init(_ storage: Storage) {
        self.storage = storage
    }

    /// Scroll indicator visibility depends on the platform — in a terminal,
    /// the indicator is shown whenever the content scrolls.
    public static let automatic = ScrollIndicatorVisibility(.automatic)
    /// Scroll indicators are shown whenever the content scrolls.
    public static let visible = ScrollIndicatorVisibility(.visible)
    /// Scroll indicators are hidden.
    public static let hidden = ScrollIndicatorVisibility(.hidden)
    /// Scroll indicators are never shown.
    public static let never = ScrollIndicatorVisibility(.never)

    /// Whether a scroll view with this visibility draws its scrollbar.
    var showsIndicator: Bool {
        switch storage {
        case .automatic, .visible: return true
        case .hidden, .never: return false
        }
    }
}

// MARK: - Environment

private struct VerticalScrollIndicatorVisibilityKey: EnvironmentKey {
    static var defaultValue: ScrollIndicatorVisibility { .automatic }
}

private struct HorizontalScrollIndicatorVisibilityKey: EnvironmentKey {
    static var defaultValue: ScrollIndicatorVisibility { .automatic }
}

public extension EnvironmentValues {
    /// The visibility to apply to vertical scroll indicators of scrollable
    /// views (``ScrollView``, ``List``, ``Table``, ``TextEditor``) in this
    /// environment.
    var verticalScrollIndicatorVisibility: ScrollIndicatorVisibility {
        get { self[VerticalScrollIndicatorVisibilityKey.self] }
        set { self[VerticalScrollIndicatorVisibilityKey.self] = newValue }
    }

    /// The visibility to apply to horizontal scroll indicators of scrollable
    /// views in this environment.
    var horizontalScrollIndicatorVisibility: ScrollIndicatorVisibility {
        get { self[HorizontalScrollIndicatorVisibilityKey.self] }
        set { self[HorizontalScrollIndicatorVisibilityKey.self] = newValue }
    }
}

// MARK: - Modifier

public extension View {
    /// Sets the visibility of scroll indicators within this view.
    ///
    /// Like SwiftUI's, the setting flows down the environment, so it applies
    /// to every scrollable view in the subtree:
    ///
    /// ```swift
    /// VStack {
    ///     ScrollView { /* … */ }
    ///     List(items, selection: $selection) { /* … */ }
    /// }
    /// .scrollIndicators(.hidden)
    /// ```
    ///
    /// A terminal has no auto-hiding overlay scrollbars, so ``ScrollIndicatorVisibility/automatic``
    /// and ``ScrollIndicatorVisibility/visible`` both draw the bar, and
    /// ``ScrollIndicatorVisibility/hidden`` and ``ScrollIndicatorVisibility/never``
    /// both leave it out. Keyboard and wheel scrolling work either way.
    ///
    /// - Parameters:
    ///   - visibility: The visibility to apply to scrollable views.
    ///   - axes: The axes of scrollable views the visibility applies to.
    ///     Defaults to both.
    func scrollIndicators(_ visibility: ScrollIndicatorVisibility, axes: Axis.Set = [.vertical, .horizontal]) -> some View {
        transformEnvironment(\.self) { environment in
            if axes.contains(.vertical) {
                environment.verticalScrollIndicatorVisibility = visibility
            }
            if axes.contains(.horizontal) {
                environment.horizontalScrollIndicatorVisibility = visibility
            }
        }
    }
}
