//
//  Sheet.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/11.
//

import Foundation

public extension View {
    /// Presents a modal sheet when `isPresented` is `true`, with the same
    /// shape as SwiftUI's `sheet(isPresented:onDismiss:content:)`.
    ///
    /// The sheet's content renders inside a rounded-border card. Its
    /// placement follows the session's rendering mode — and unlike
    /// ``NavigationLink`` no enclosing navigation container is needed:
    ///
    /// - **Inline** (or a one-shot render): the card is **appended below**
    ///   the view. The view stays visible but its controls are disabled —
    ///   they leave the focus ring and no longer count for the session's
    ///   idle check, so only the sheet's controls matter while it is up.
    /// - **Full-screen**: the card **replaces** the view, like a modal
    ///   covering the screen.
    ///
    /// Presenting moves focus to the sheet's first control; dismissing
    /// (setting the binding back to `false`) restores the view's controls
    /// and focus.
    ///
    /// In a full-screen session, `@Environment(\.dismiss)` read inside the
    /// sheet **closes the sheet** (sets the binding to `false`) instead of
    /// ending the session — capture it in the action that uses it:
    ///
    /// ```swift
    /// Button("Done") { [dismiss] in dismiss() }
    /// ```
    ///
    /// ```swift
    /// @State var showsSettings = false
    ///
    /// var body: some View {
    ///     MainView()
    ///         .sheet(isPresented: $showsSettings) {
    ///             SettingsForm()
    ///             Button("Done") { showsSettings = false }
    ///         }
    /// }
    /// ```
    ///
    /// Each call site is its own sheet: presentation transitions are tracked
    /// per source location, so a screen may define several sheets without
    /// naming them.
    ///
    /// - Parameters:
    ///   - isPresented: A binding that controls whether the sheet is shown.
    ///   - onDismiss: Called when the sheet transitions to dismissed.
    ///   - content: A ``ViewBuilder`` producing the sheet's content.
    func sheet<Content: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        @ViewBuilder content: () -> Content
    ) -> some View {
        modifier(SheetModifier(
            isPresented: isPresented,
            id: "\(fileID):\(line):\(column)",
            onDismiss: onDismiss,
            sheet: AnyView(content())
        ))
    }
}

/// Tracks each sheet's last observed presentation state, so the modifier can
/// react to transitions (moving focus into the sheet on present, back to the
/// base view on dismiss) exactly once per change.
final class SheetPresentationTracker: @unchecked Sendable {
    static let shared = SheetPresentationTracker()

    private let lock = NSLock()
    private var presented: [String: Bool] = [:]

    private init() {}

    /// Records `isPresented` for `id` and returns whether it changed since
    /// the last observation. The very first observation is not a transition.
    func observe(id: String, isPresented: Bool) -> Bool {
        lock.lock(); defer { lock.unlock() }
        let previous = presented[id]
        presented[id] = isPresented
        guard let previous else { return false }
        return previous != isPresented
    }

    /// Clears all tracked presentation state.
    func reset() {
        lock.lock(); defer { lock.unlock() }
        presented.removeAll()
    }
}

/// Lays a view out with its sheet card appended below (inline) or replacing
/// it (full-screen) while the sheet is presented.
struct SheetModifier: ViewModifier {
    let isPresented: Binding<Bool>
    let id: String
    let onDismiss: (() -> Void)?
    let sheet: AnyView

    func node(for content: RenderNode) -> RenderNode {
        content
    }

    func node(lowering content: () -> RenderNode) -> RenderNode {
        let presented = isPresented.wrappedValue

        // A presentation transition rebuilds the focus ring, so focus moves
        // into the sheet on present and back to the base view on dismiss.
        if SheetPresentationTracker.shared.observe(id: id, isPresented: presented) {
            FocusCoordinator.shared.prepareForNewLayer()
            if !presented { onDismiss?() }
        }

        guard presented else { return content() }

        // The sheet content renders as a rounded-border card.
        let card = AnyView(sheet).padding().border(.primary)
        if BodyRenderingStore.shared.fullScreenActive {
            // Full-screen: the sheet covers the view, and `\.dismiss` inside
            // it closes the sheet instead of ending the session.
            let isPresented = isPresented
            return card
                .environment(\.dismiss, DismissAction { isPresented.wrappedValue = false })
                .makeNode()
        } else {
            // Inline: the card is appended below; the base view stays
            // visible but its controls render inert.
            let base = FocusCoordinator.shared.withRegistrationSuppressed { content() }
            return .vstack(alignment: .leading, spacing: 0, children: [base, card.lowered(at: 1)])
        }
    }
}
