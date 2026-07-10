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
    let header: String
    let label: String
    let destination: String

    /// Creates a hyperlink with a localized label and a destination URL.
    ///
    /// - Parameters:
    ///   - label: The visible, localized text.
    ///   - destination: The URL opened when the link is activated.
    public init(_ label: LocalizedStringKey, destination: String) {
        self.header = ""
        self.label = String(localized: label.localizationValue)
        self.destination = destination
    }

    init(header: String, label: String, destination: String) {
        self.header = header
        self.label = label
        self.destination = destination
    }

    /// The OSC 8 "open" sequence carrying the destination, terminated by ST.
    private var openSequence: String {
        "\u{001B}]8;;\(destination)\u{001B}\\"
    }

    public var body: some View {
        EmptyView()
    }

    @_spi(RenderingInternals)
    public func addHeader(_ header: String) -> Self {
        .init(header: header + self.header, label: label, destination: destination)
    }

    /// Lowers to a styled ``RenderNode/text`` whose header opens the OSC 8
    /// hyperlink. The rendering pipeline measures only the label's width (the
    /// escape occupies no columns) and the canvas emits each label cell as a
    /// self-contained clickable unit.
    ///
    /// Inside a reactive runtime the link additionally registers itself in the
    /// focus ring so <kbd>Return</kbd>/<kbd>Space</kbd> open the destination.
    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        var head = header
        let interactive = AppRuntime.shared != nil || BodyRenderingStore.shared.sessionActive
        if interactive {
            let id = "Link:\(destination):\(label)"
            let destination = self.destination
            FocusCoordinator.shared.registerButton(id: id) {
                LinkOpener.handler(destination)
            }
            KeyInputRouter.shared.ensureStarted()
            if FocusCoordinator.shared.isFocused(id) {
                // Focused: cyan + underline, like a highlighted hyperlink.
                head = "\u{001B}[36m\u{001B}[4m" + head
            }
        }
        return .text(header: openSequence + head, contents: [label])
    }
}

/// Opens a ``Link``'s destination. The handler is swappable so tests can
/// observe activations without launching the system opener.
enum LinkOpener {
    /// Launches the system `open` command with the destination.
    nonisolated(unsafe) static var handler: (String) -> Void = { destination in
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [destination]
        try? process.run()
    }
}
