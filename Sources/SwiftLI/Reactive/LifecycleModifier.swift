//
//  LifecycleModifier.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2024/05/27.
//

import Foundation

/// A view wrapper that executes an action the first time it is rendered.
///
/// `OnAppearView` is created by the `onAppear(perform:)` modifier and should
/// not normally be instantiated directly.
///
/// The action is called exactly once, on the first call to `render()`. This is
/// useful for starting timers, kicking off animations, or scheduling any work
/// that should happen only when the view becomes visible.
///
/// ```swift
/// Group {
///     Text("Loading...").newLine()
/// }
/// .onAppear {
///     myTimer.start { progress += 0.1 }
/// }
/// ```
public struct OnAppearView: View {
    private let content: [any View]
    private let action: () -> Void
    /// Tracks which `OnAppearView` instances have already fired their action.
    /// Using a class-based token as identity avoids relying on struct memory addresses.
    nonisolated(unsafe) private static var appearedKeys = Set<ObjectIdentifier>()
    private let key: ObjectIdentifier
    /// Keeps the token alive for the lifetime of this view.
    private let token: OnAppearToken

    init(content: [any View], action: @escaping () -> Void) {
        let t = OnAppearToken()
        self.token = t
        self.key = ObjectIdentifier(t)
        self.content = content
        self.action = action
    }

    public var body: some View {
        // makeNode() is overridden, so body is not used by the runtime.
        EmptyView()
    }

    /// Lowers the wrapped content, firing the appear action exactly once on the
    /// first lowering.
    ///
    /// `makeNode()` is the single point every render pass funnels through, so
    /// firing here (guarded by ``appearedKeys``) reliably runs the action the
    /// first time the view is drawn.
    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        if !Self.appearedKeys.contains(key) {
            Self.appearedKeys.insert(key)
            action()
        }
        return .group(children: content.map { $0.makeNode() })
    }
}

/// Private identity token for `OnAppearView`.
private final class OnAppearToken {}

// MARK: - View Extension

public extension View {
    /// Adds an action to perform when this view first appears on screen.
    ///
    /// The action fires exactly once — on the first call to `render()`. In the
    /// reactive system, "first render" corresponds to the first time the runtime
    /// draws the view tree after the app starts.
    ///
    /// - Parameter action: The closure to execute when the view first appears.
    /// - Returns: A modified view that calls `action` before its first render.
    func onAppear(perform action: @escaping () -> Void) -> OnAppearView {
        OnAppearView(content: [self], action: action)
    }
}
