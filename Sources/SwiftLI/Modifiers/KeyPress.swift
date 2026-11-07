//
//  KeyPress.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/11/07.
//

import Foundation

// MARK: - KeyEquivalent

/// A key on the keyboard, mirroring SwiftUI's `KeyEquivalent`.
///
/// Printable keys are written as character literals (`"q"`); the
/// non-printing keys have named constants (``escape``, ``upArrow``,
/// ``return``, …) whose characters match the ones SwiftUI reports.
public struct KeyEquivalent: Hashable, Sendable, ExpressibleByExtendedGraphemeClusterLiteral {
    /// The character the key produces.
    public let character: Character

    /// Creates a key equivalent from a character.
    public init(_ character: Character) {
        self.character = character
    }

    public init(extendedGraphemeClusterLiteral value: Character) {
        self.character = value
    }

    /// Up arrow.
    public static let upArrow = KeyEquivalent("\u{F700}")
    /// Down arrow.
    public static let downArrow = KeyEquivalent("\u{F701}")
    /// Left arrow.
    public static let leftArrow = KeyEquivalent("\u{F702}")
    /// Right arrow.
    public static let rightArrow = KeyEquivalent("\u{F703}")
    /// Escape.
    public static let escape = KeyEquivalent("\u{1B}")
    /// Delete / Backspace (delete backward).
    public static let delete = KeyEquivalent("\u{7F}")
    /// Forward delete.
    public static let deleteForward = KeyEquivalent("\u{F728}")
    /// Home.
    public static let home = KeyEquivalent("\u{F729}")
    /// End.
    public static let end = KeyEquivalent("\u{F72B}")
    /// Page Up.
    public static let pageUp = KeyEquivalent("\u{F72C}")
    /// Page Down.
    public static let pageDown = KeyEquivalent("\u{F72D}")
    /// Clear.
    public static let clear = KeyEquivalent("\u{F739}")
    /// Tab.
    public static let tab = KeyEquivalent("\t")
    /// Space.
    public static let space = KeyEquivalent(" ")
    /// Return / Enter.
    public static let `return` = KeyEquivalent("\r")
}

// MARK: - EventModifiers

/// The modifier keys held during an event, mirroring SwiftUI's
/// `EventModifiers`.
///
/// A terminal reports only what its input protocol encodes: ``control``
/// for Control chords (<kbd>Ctrl-S</kbd> arrives as `"s"` with `.control`)
/// and ``shift`` for Shift-Tab and shifted letters. The other modifiers are
/// declared for API parity and never set.
public struct EventModifiers: OptionSet, Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// The Caps Lock key.
    public static let capsLock = EventModifiers(rawValue: 1)
    /// The Shift key.
    public static let shift = EventModifiers(rawValue: 2)
    /// The Control key.
    public static let control = EventModifiers(rawValue: 4)
    /// The Option key.
    public static let option = EventModifiers(rawValue: 8)
    /// The Command key.
    public static let command = EventModifiers(rawValue: 16)
    /// A key on the numeric keypad.
    public static let numericPad = EventModifiers(rawValue: 32)
    /// The Function key.
    public static let function = EventModifiers(rawValue: 64)
    /// All modifier keys.
    public static let all: EventModifiers = [.capsLock, .shift, .control, .option, .command, .numericPad, .function]
}

// MARK: - KeyPress

/// A key press delivered to an ``View/onKeyPress(action:)`` handler,
/// mirroring SwiftUI's `KeyPress`.
public struct KeyPress: Sendable {

    /// The phase of a key press, mirroring SwiftUI's `KeyPress.Phase`.
    ///
    /// A terminal reports a key only when it goes down — there are no
    /// key-up or auto-repeat events in the input stream — so every press
    /// SwiftLI delivers is ``down``.
    public enum Phase: Hashable, Sendable {
        /// The key was pressed.
        case down
        /// The key is being held and auto-repeating.
        case `repeat`
        /// The key was released.
        case up
    }

    /// A set of key-press phases, mirroring SwiftUI's `KeyPress.Phases`.
    public struct Phases: OptionSet, Hashable, Sendable {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        /// The key was pressed.
        public static let down = Phases(rawValue: 1)
        /// The key is being held and auto-repeating.
        public static let `repeat` = Phases(rawValue: 2)
        /// The key was released.
        public static let up = Phases(rawValue: 4)
        /// Every phase.
        public static let all: Phases = [.down, .repeat, .up]
    }

    /// The result of a key-press handler, mirroring SwiftUI's
    /// `KeyPress.Result`.
    public enum Result: Sendable {
        /// The handler consumed the key; no outer handler sees it.
        case handled
        /// The handler did not use the key; it propagates to the next handler.
        case ignored
    }

    /// The phase of the press — always ``Phase/down`` in a terminal.
    public let phase: Phase
    /// The key that was pressed, ignoring modifiers.
    public let key: KeyEquivalent
    /// The characters the key produces, with modifiers applied.
    public let characters: String
    /// The modifier keys held during the press.
    public let modifiers: EventModifiers

    init(phase: Phase = .down, key: KeyEquivalent, characters: String? = nil, modifiers: EventModifiers = []) {
        self.phase = phase
        self.key = key
        self.characters = characters ?? String(key.character)
        self.modifiers = modifiers
    }

    /// The press a decoded ``KeyEvent`` corresponds to, or `nil` for events
    /// that are not key presses (pointer reports, terminal replies).
    ///
    /// Control chords map back to their letter plus ``EventModifiers/control``
    /// — including the ones the line editor decodes into editing events —
    /// so a handler can bind <kbd>Ctrl-K</kbd> the same way as <kbd>Ctrl-S</kbd>.
    init?(_ event: KeyEvent) {
        switch event {
        case .character(let c):
            self.init(key: KeyEquivalent(c), modifiers: c.isUppercase ? [.shift] : [])
        case .control(let c):
            self.init(key: KeyEquivalent(c), modifiers: [.control])
        case .backspace:          self.init(key: .delete)
        case .delete:             self.init(key: .deleteForward)
        case .deleteToStart:      self.init(key: "u", modifiers: [.control])
        case .deleteToEnd:        self.init(key: "k", modifiers: [.control])
        case .deleteWordBackward: self.init(key: "w", modifiers: [.control])
        case .left:               self.init(key: .leftArrow)
        case .right:              self.init(key: .rightArrow)
        case .up:                 self.init(key: .upArrow)
        case .down:               self.init(key: .downArrow)
        case .home:               self.init(key: .home)
        case .end:                self.init(key: .end)
        case .pageUp:             self.init(key: .pageUp)
        case .pageDown:           self.init(key: .pageDown)
        case .enter:              self.init(key: .return)
        case .tab:                self.init(key: .tab)
        case .backTab:            self.init(key: .tab, modifiers: [.shift])
        case .escape:             self.init(key: .escape)
        case .interrupt:          self.init(key: "c", modifiers: [.control])
        case .mouse, .cursorPosition:
            return nil
        }
    }
}

// MARK: - KeyPressModifier

/// Registers a key-press handler for the frame its content appears in.
/// Created by the `onKeyPress` family of modifiers.
struct KeyPressModifier: ViewModifier {
    let phases: KeyPress.Phases
    let action: (KeyPress) -> KeyPress.Result

    func node(for content: RenderNode) -> RenderNode {
        content
    }

    func node(lowering content: () -> RenderNode) -> RenderNode {
        // An inert navigation layer registers neither its controls nor its
        // key handlers — only the active layer reacts to the keyboard.
        guard !FocusCoordinator.shared.isRegistrationSuppressed else {
            return content()
        }
        // The handler runs later, from the input loop, where no view is being
        // lowered — so an `@Environment` value read inside it (`dismiss`,
        // most importantly) would otherwise resolve to the root default
        // instead of what this view sees. Snapshot the environment in effect
        // here and run the handler inside it, as SwiftUI's handlers do.
        let environment = EnvironmentStack.current
        let phases = phases
        let action = action
        let token = KeyPressRegistry.shared.push { press in
            guard phases.contains(.down) else { return .ignored }
            return EnvironmentStack.with(environment) { action(press) }
        }
        let node = content()
        KeyPressRegistry.shared.pop(token)
        // Like a control, a handler needs the keyboard read — an inline
        // session only starts the reader once something on screen wants keys.
        if token != nil { KeyInputRouter.shared.ensureStarted() }
        return node
    }
}

// MARK: - View extension

public extension View {
    /// Performs an action when a specific key is pressed, mirroring SwiftUI's
    /// `onKeyPress(_:action:)`.
    ///
    /// ```swift
    /// Text("Press q to quit")
    ///     .onKeyPress("q") { dismiss(); return .handled }
    /// ```
    ///
    /// See ``onKeyPress(action:)`` for how keys reach handlers.
    ///
    /// - Parameters:
    ///   - key: The key the handler responds to; every other key is ignored.
    ///   - action: Called when `key` is pressed; returns whether it consumed
    ///     the press.
    func onKeyPress(_ key: KeyEquivalent, action: @escaping () -> KeyPress.Result) -> some View {
        onKeyPress(keys: [key]) { _ in action() }
    }

    /// Performs an action when a specific key is pressed in one of the given
    /// phases, mirroring SwiftUI's `onKeyPress(_:phases:action:)`.
    ///
    /// A terminal only reports ``KeyPress/Phase/down``; a `phases` set
    /// without it never fires.
    func onKeyPress(_ key: KeyEquivalent, phases: KeyPress.Phases, action: @escaping (KeyPress) -> KeyPress.Result) -> some View {
        onKeyPress(keys: [key], phases: phases, action: action)
    }

    /// Performs an action when any key in `keys` is pressed, mirroring
    /// SwiftUI's `onKeyPress(keys:phases:action:)`.
    ///
    /// ```swift
    /// List(posts, selection: $selected) { post in Text(post.title) }
    ///     .onKeyPress(keys: [.upArrow, .downArrow, "j", "k"]) { press in
    ///         move(press.key == .downArrow || press.key == "j" ? 1 : -1)
    ///         return .handled
    ///     }
    /// ```
    func onKeyPress(keys: Set<KeyEquivalent>, phases: KeyPress.Phases = [.down, .repeat], action: @escaping (KeyPress) -> KeyPress.Result) -> some View {
        modifier(KeyPressModifier(phases: phases) { press in
            keys.contains(press.key) ? action(press) : .ignored
        })
    }

    /// Performs an action when a key producing one of `characters` is
    /// pressed, mirroring SwiftUI's `onKeyPress(characters:phases:action:)`.
    ///
    /// ```swift
    /// Text("1–9 jumps to a tab")
    ///     .onKeyPress(characters: .decimalDigits) { press in
    ///         select(tab: Int(press.characters)!)
    ///         return .handled
    ///     }
    /// ```
    func onKeyPress(characters: CharacterSet, phases: KeyPress.Phases = [.down, .repeat], action: @escaping (KeyPress) -> KeyPress.Result) -> some View {
        modifier(KeyPressModifier(phases: phases) { press in
            let matches = !press.characters.isEmpty
                && press.characters.unicodeScalars.allSatisfy { characters.contains($0) }
            return matches ? action(press) : .ignored
        })
    }

    /// Performs an action when any key is pressed in one of the given phases,
    /// mirroring SwiftUI's `onKeyPress(phases:action:)`.
    func onKeyPress(phases: KeyPress.Phases, action: @escaping (KeyPress) -> KeyPress.Result) -> some View {
        modifier(KeyPressModifier(phases: phases, action: action))
    }

    /// Receives the keys the focused control did not handle, mirroring
    /// SwiftUI's `onKeyPress(action:)`.
    ///
    /// Every key the user presses goes to the focused control first (a
    /// ``TextField`` inserts characters, a ``List`` moves its selection, …).
    /// A key that control does not use — <kbd>Return</kbd> on a list row, a
    /// letter while a button has focus, anything while nothing is focused —
    /// is offered to the `onKeyPress` handlers on screen: first those
    /// enclosing the focused control, innermost first, then the rest of the
    /// frame. Returning ``KeyPress/Result/handled`` stops the propagation;
    /// ``KeyPress/Result/ignored`` passes the key on.
    ///
    /// ```swift
    /// List(posts, selection: $selected) { post in Text(post.title) }
    ///     .onKeyPress { press in
    ///         switch press.key {
    ///         case .return: open(selected);  return .handled
    ///         case "r":     reload();        return .handled
    ///         default:                       return .ignored
    ///         }
    ///     }
    /// ```
    ///
    /// Control chords arrive as their letter with
    /// ``EventModifiers/control`` set (`press.modifiers.contains(.control)`).
    /// Handlers only receive keys from the active navigation layer — a
    /// handler beneath a pushed destination is silent until the destination
    /// is popped — and run in the environment of the view they modify, so
    /// `@Environment(\.dismiss)` read inside one pops or closes what it
    /// would from `body`. A frame that contains a handler keeps an
    /// ``InlineCommand``/``FullScreenCommand`` session alive, just as an
    /// interactive control does.
    ///
    /// - Parameter action: Called with each unhandled ``KeyPress``; returns
    ///   whether it consumed the press.
    func onKeyPress(action: @escaping (KeyPress) -> KeyPress.Result) -> some View {
        modifier(KeyPressModifier(phases: [.down, .repeat], action: action))
    }
}
