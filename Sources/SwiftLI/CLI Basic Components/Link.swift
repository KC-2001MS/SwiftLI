//
//  Link.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/09.
//

import Foundation

/// A clickable hyperlink rendered with the terminal's OSC 8 escape sequence.
///
/// `Link` displays `label` and associates it with `destination` so that, on a
/// terminal that supports OSC 8 hyperlinks, the text is clickable (Cmd/Ctrl-click
/// or the terminal's own affordance) and opens the URL.
///
/// ```swift
/// Link("Apple", destination: "https://apple.com")
///     .forgroundColor(.blue)
///     .underline()
///     .render()
/// ```
///
/// ## Terminal support
///
/// OSC 8 is honoured by iTerm2, kitty, WezTerm, Ghostty, VTE-based terminals
/// (GNOME Terminal), Windows Terminal, and others. The **macOS Terminal.app**
/// does *not* support it: the sequence is ignored and only the plain `label`
/// text shows — a graceful degradation, since the label still renders and takes
/// the same width either way.
///
/// ## Keyboard activation
///
/// Inside a reactive runtime (a ``CLIApp`` or a ``InlineCommand``/``FullScreenCommand`` session),
/// a link joins the focus ring like a ``Button``: <kbd>Tab</kbd> reaches it
/// (shown cyan and underlined) and <kbd>Return</kbd> or <kbd>Space</kbd> opens
/// the destination with the system `open` command. A one-shot `render()`
/// outside a runtime keeps the plain, non-focusable output above.
public struct Link: View, Sendable {
    let style: TextStyle
    let label: String
    let destination: String

    /// Creates a hyperlink with a localized label and a destination URL.
    ///
    /// - Parameters:
    ///   - label: The visible, localized text.
    ///   - destination: The URL opened when the link is activated.
    public init(_ label: LocalizedStringKey, destination: String) {
        self.style = .plain
        self.label = String(localized: label.localizationValue)
        self.destination = destination
    }

    init(style: TextStyle, label: String, destination: String) {
        self.style = style
        self.label = label
        self.destination = destination
    }

    /// The content of this view; always empty because ``Link`` is rendered
    /// entirely through ``makeNode()``.
    public var body: some View {
        EmptyView()
    }

    @_spi(RenderingInternals)
    public func applyingStyle(_ style: TextStyle) -> Self {
        .init(style: self.style.inheriting(style), label: label, destination: destination)
    }

    /// Lowers to a styled ``RenderNode/text`` whose style carries the OSC 8
    /// hyperlink destination. The rendering pipeline measures only the label's
    /// width (the escape occupies no columns) and the canvas emits each label
    /// cell as a self-contained clickable unit.
    ///
    /// Inside a reactive runtime the link additionally registers itself in the
    /// focus ring so <kbd>Return</kbd>/<kbd>Space</kbd> open the destination.
    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        var resolved = style
        let interactive = AppRuntime.shared != nil || BodyRenderingStore.shared.sessionActive
        var controlID: String?
        if interactive {
            let id = "Link:\(destination):\(label)"
            let destination = self.destination
            FocusCoordinator.shared.registerButton(id: id) {
                LinkOpener.handler(destination)
            }
            KeyInputRouter.shared.ensureStarted()
            controlID = id
            if FocusCoordinator.shared.isFocused(id) {
                // Focused: cyan + underline, like a highlighted hyperlink —
                // a fallback the link's own style overrides.
                resolved = resolved.inheriting(TextStyle(foreground: .cyan, isUnderlined: true))
            }
        }
        if resolved.link == nil {
            resolved.link = destination
        }
        let node = RenderNode.text(style: resolved.resolving(), contents: [label])
        return controlID.map { node.asControl(id: $0) } ?? node
    }
}

/// Opens a ``Link``'s destination. The handler is swappable so tests can
/// observe activations without launching the system opener.
enum LinkOpener {
    /// Launches the system URL opener with the destination.
    ///
    /// Uses `open` on macOS and `xdg-open` on Linux.
    nonisolated(unsafe) static var handler: (String) -> Void = { destination in
        let process = Process()
        #if os(macOS)
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [destination]
        #elseif os(Windows)
        // cmd /c start "" <url> opens the URL in the default browser.
        process.executableURL = URL(fileURLWithPath: "C:\\Windows\\System32\\cmd.exe")
        process.arguments = ["/c", "start", "", destination]
        #else
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xdg-open")
        process.arguments = [destination]
        #endif
        try? process.run()
    }
}
