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
///     .foregroundStyle(.blue)
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
        self.label = label.resolve()
        self.destination = destination
    }

    init(style: TextStyle, label: String, destination: String) {
        self.style = style
        self.label = label
        self.destination = destination
    }

    /// A ``Text`` whose style carries the OSC 8 hyperlink destination. The
    /// rendering pipeline measures only the label's width (the escape occupies
    /// no columns) and emits the label as a clickable run.
    ///
    /// Inside a reactive runtime the link additionally registers itself in the
    /// focus ring so <kbd>Return</kbd>/<kbd>Space</kbd> open the destination,
    /// and marks the text as its pointer footprint.
    public var body: some View {
        Text(style: resolvedStyle, content: label)
    }

    /// Whether a reactive runtime is active, so the link joins the focus ring.
    private var isInteractive: Bool {
        AppRuntime.shared != nil || BodyRenderingStore.shared.sessionActive
    }

    private var controlID: String {
        "Link:\(destination):\(label)"
    }

    /// The link's style: the destination attached and — while focused — cyan
    /// + underline as a fallback, like a highlighted hyperlink, which the
    /// link's own style overrides.
    private var resolvedStyle: TextStyle {
        var resolved = style
        if isInteractive && FocusCoordinator.shared.isFocused(controlID) {
            resolved = resolved.inheriting(TextStyle(foreground: .cyan, isUnderlined: true))
        }
        if resolved.link == nil {
            resolved.link = destination
        }
        return resolved
    }

    @_spi(RenderingInternals)
    public func applyingStyle(_ style: TextStyle) -> Self {
        .init(style: self.style.inheriting(style), label: label, destination: destination)
    }

    /// Inside a reactive runtime, registers the link in the focus ring so
    /// <kbd>Return</kbd>/<kbd>Space</kbd> open the destination, and lowers
    /// ``body`` as the link's pointer footprint; otherwise lowers it plain.
    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        guard isInteractive else { return body.makeNode() }
        let destination = self.destination
        FocusCoordinator.shared.registerButton(id: controlID) {
            LinkOpener.handler(destination)
        }
        KeyInputRouter.shared.ensureStarted()
        return body.makeNode().asControl(id: controlID)
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
