//
//  Alert.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/11/08.
//

import Foundation

/// Whether an element is shown, mirroring SwiftUI's `Visibility`.
public struct Visibility: Equatable, Sendable {
    private enum Kind: Equatable, Sendable { case automatic, visible, hidden }
    private let kind: Kind

    /// The element decides (a dialog title is shown).
    public static let automatic = Visibility(kind: .automatic)
    /// Shown.
    public static let visible = Visibility(kind: .visible)
    /// Hidden.
    public static let hidden = Visibility(kind: .hidden)

    var isHidden: Bool { kind == .hidden }
}

// MARK: - Auto-dismissing actions

private struct PresentationAutoDismissKey: EnvironmentKey {
    static var defaultValue: (() -> Void)? { nil }
}

extension EnvironmentValues {
    /// Set inside an alert's or confirmation dialog's actions: a ``Button``
    /// runs it after its own action, so activating any action dismisses the
    /// presentation as in SwiftUI.
    var presentationAutoDismiss: (() -> Void)? {
        get { self[PresentationAutoDismissKey.self] }
        set { self[PresentationAutoDismissKey.self] = newValue }
    }
}

// MARK: - Modal card presentation

/// Presents a card — an alert or a confirmation dialog — while a binding is
/// `true`: centred over the content in a full-screen session, appended
/// below it inline. The content's controls are inert while the card is up,
/// focus moves into the card, any action button dismisses it, and so does
/// <kbd>Escape</kbd>.
struct ModalCardModifier: ViewModifier {
    enum Kind { case alert, confirmationDialog }

    let kind: Kind
    let title: String
    let titleVisibility: Visibility
    let isPresented: Binding<Bool>
    let id: String
    let actions: [any View]
    let message: AnyView?

    func node(for content: RenderNode) -> RenderNode {
        content
    }

    func node(lowering content: () -> RenderNode) -> RenderNode {
        let presented = isPresented.wrappedValue
        if SheetPresentationTracker.shared.observe(id: id, isPresented: presented) {
            FocusCoordinator.shared.prepareForNewLayer()
        }
        guard presented else { return content() }

        let isPresented = isPresented
        let dismiss: @Sendable () -> Void = { isPresented.wrappedValue = false }

        var rows: [any View] = []
        if !titleVisibility.isHidden, !title.isEmpty {
            rows.append(Text(content: title).bold())
        }
        if let message {
            rows.append(message.foregroundStyle(.secondary))
        }
        if !actions.isEmpty {
            // Alerts line their buttons up; a dialog lists them, like a menu.
            let buttons: any View = kind == .alert
                ? HStack(alignment: .top, spacing: 2, children: actions, style: .plain)
                : VStack(alignment: .leading, spacing: 0, children: actions, style: .plain)
            rows.append(AnyView(buttons).padding(.top, rows.isEmpty ? 0 : 1))
        }
        let card = VStack(alignment: .leading, spacing: 0, children: rows)
            .padding()
            .border(.primary)
            .environment(\.presentationAutoDismiss, dismiss)
            .environment(\.dismiss, DismissAction { dismiss() })
            .onKeyPress(.escape) { dismiss(); return .handled }

        // The content stays visible but inert beneath the card.
        let base = FocusCoordinator.shared.withRegistrationSuppressed { content() }
        if BodyRenderingStore.shared.fullScreenActive {
            return .zstack(alignment: .center, children: [base, card.lowered(at: 1)])
        }
        return .vstack(alignment: .leading, spacing: 0, children: [base, card.lowered(at: 1)])
    }
}

public extension View {
    /// Presents an alert with a title, a message and action buttons while
    /// `isPresented` is `true`, mirroring SwiftUI's
    /// `alert(_:isPresented:actions:message:)`.
    ///
    /// Activating any action dismisses the alert (SwiftUI's behaviour), as
    /// does <kbd>Escape</kbd>. Full-screen, the alert is a card centred over
    /// the content; inline it is appended below.
    ///
    /// ```swift
    /// .alert("Delete \(item.title)?", isPresented: $confirmDelete) {
    ///     Button("Delete", role: .destructive) { model.delete(item) }
    ///     Button("Cancel", role: .cancel) {}
    /// } message: {
    ///     Text("This cannot be undone.")
    /// }
    /// ```
    func alert<A: View, M: View>(
        _ title: LocalizedStringKey,
        isPresented: Binding<Bool>,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        @ViewBuilder actions: () -> A,
        @ViewBuilder message: () -> M
    ) -> some View {
        modifier(ModalCardModifier(
            kind: .alert, title: title.resolve(), titleVisibility: .visible, isPresented: isPresented,
            id: "alert:\(fileID):\(line):\(column)", actions: actions()._flattenedChildren(), message: AnyView(message())
        ))
    }

    /// Presents an alert with a title and action buttons while `isPresented`
    /// is `true`, mirroring SwiftUI's `alert(_:isPresented:actions:)`.
    func alert<A: View>(
        _ title: LocalizedStringKey,
        isPresented: Binding<Bool>,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        @ViewBuilder actions: () -> A
    ) -> some View {
        modifier(ModalCardModifier(
            kind: .alert, title: title.resolve(), titleVisibility: .visible, isPresented: isPresented,
            id: "alert:\(fileID):\(line):\(column)", actions: actions()._flattenedChildren(), message: nil
        ))
    }

    /// Presents a confirmation dialog — a list of actions under a title —
    /// while `isPresented` is `true`, mirroring SwiftUI's
    /// `confirmationDialog(_:isPresented:titleVisibility:actions:message:)`.
    ///
    /// Activating any action dismisses the dialog, as does <kbd>Escape</kbd>.
    /// Pair it with ``onKeyPress(_:action:)`` on the actions for `y`/`n`
    /// shortcuts.
    func confirmationDialog<A: View, M: View>(
        _ title: LocalizedStringKey,
        isPresented: Binding<Bool>,
        titleVisibility: Visibility = .automatic,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        @ViewBuilder actions: () -> A,
        @ViewBuilder message: () -> M
    ) -> some View {
        modifier(ModalCardModifier(
            kind: .confirmationDialog, title: title.resolve(), titleVisibility: titleVisibility, isPresented: isPresented,
            id: "dialog:\(fileID):\(line):\(column)", actions: actions()._flattenedChildren(), message: AnyView(message())
        ))
    }

    /// Presents a confirmation dialog while `isPresented` is `true`,
    /// mirroring SwiftUI's `confirmationDialog(_:isPresented:titleVisibility:actions:)`.
    func confirmationDialog<A: View>(
        _ title: LocalizedStringKey,
        isPresented: Binding<Bool>,
        titleVisibility: Visibility = .automatic,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        @ViewBuilder actions: () -> A
    ) -> some View {
        modifier(ModalCardModifier(
            kind: .confirmationDialog, title: title.resolve(), titleVisibility: titleVisibility, isPresented: isPresented,
            id: "dialog:\(fileID):\(line):\(column)", actions: actions()._flattenedChildren(), message: nil
        ))
    }
}
