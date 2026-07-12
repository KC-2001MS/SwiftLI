//
//  KeyDecoder.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/07.
//

/// Incrementally decodes raw terminal input bytes into ``KeyEvent`` values.
///
/// Terminal input arrives as a byte stream in which a single logical key can
/// span several bytes — a multi-byte UTF-8 character, or a multi-byte escape
/// sequence such as `ESC [ C` for the right arrow. `KeyDecoder` buffers any
/// incomplete tail between calls to ``feed(_:)``, so callers can hand it
/// whatever `read()` returned without worrying about sequence boundaries.
///
/// It is a pure state machine (no I/O), which makes the entire input-parsing
/// layer unit-testable.
public struct KeyDecoder: Sendable {

    /// Bytes carried over from a previous `feed` that did not yet form a
    /// complete key (a split UTF-8 character or escape sequence).
    private var pending: [UInt8] = []

    /// Creates a new, empty `KeyDecoder` with no pending bytes.
    public init() {}

    /// Feeds raw bytes and returns every fully-decoded key event.
    ///
    /// Any trailing bytes that form an incomplete character or escape sequence
    /// are retained internally and completed on a subsequent call.
    public mutating func feed(_ bytes: [UInt8]) -> [KeyEvent] {
        pending.append(contentsOf: bytes)
        var events: [KeyEvent] = []
        var i = 0

        while i < pending.count {
            let b = pending[i]

            switch b {
            case 0x03: events.append(.interrupt);  i += 1
            case 0x09: events.append(.tab);        i += 1
            case 0x0A, 0x0D: events.append(.enter); i += 1
            case 0x08, 0x7F: events.append(.backspace); i += 1

            // Emacs/readline control-key line editing, matching what users
            // expect from a normal terminal prompt.
            case 0x01: events.append(.home);              i += 1 // Ctrl-A
            case 0x05: events.append(.end);               i += 1 // Ctrl-E
            case 0x02: events.append(.left);              i += 1 // Ctrl-B
            case 0x06: events.append(.right);             i += 1 // Ctrl-F
            case 0x04: events.append(.delete);            i += 1 // Ctrl-D
            case 0x0B: events.append(.deleteToEnd);       i += 1 // Ctrl-K
            case 0x15: events.append(.deleteToStart);     i += 1 // Ctrl-U
            case 0x17: events.append(.deleteWordBackward); i += 1 // Ctrl-W

            case 0x1B: // ESC — possibly the start of a CSI/SS3 sequence.
                let (event, consumed, needMore) = Self.parseEscape(pending, from: i)
                if needMore {
                    // Incomplete escape sequence: keep it for the next feed.
                    pending.removeFirst(i)
                    return events
                }
                if let event { events.append(event) }
                i += consumed

            default:
                if b < 0x20 {
                    // Other control byte — ignore.
                    i += 1
                } else {
                    // Printable: decode one (possibly multi-byte) UTF-8 scalar.
                    let (event, consumed, needMore) = Self.parseUTF8(pending, from: i)
                    if needMore {
                        pending.removeFirst(i)
                        return events
                    }
                    if let event { events.append(event) }
                    i += consumed
                }
            }
        }

        pending.removeAll(keepingCapacity: true)
        return events
    }

    // MARK: - Escape sequences

    /// Parses an escape sequence beginning at `start` (which must be `ESC`).
    ///
    /// - Returns: the decoded event (or `nil` to drop it), the number of bytes
    ///   consumed, and `needMore` when the buffer does not yet contain the
    ///   whole sequence.
    private static func parseEscape(_ buf: [UInt8], from start: Int) -> (event: KeyEvent?, consumed: Int, needMore: Bool) {
        // Lone ESC at the very end: wait one more byte to disambiguate a real
        // Escape key press from the start of an arrow-key sequence.
        guard start + 1 < buf.count else { return (nil, 0, true) }

        let second = buf[start + 1]
        // CSI ("ESC [") or SS3 ("ESC O") introduce cursor/function keys.
        guard second == 0x5B /* [ */ || second == 0x4F /* O */ else {
            // ESC followed by something else → treat the ESC as its own key.
            return (.escape, 1, false)
        }

        // Legacy X10 mouse report: "ESC [ M" followed by three raw bytes
        // (button+32, column+32, row+32). The 'M' would otherwise read as a
        // final byte with no parameters, leaving the three payload bytes to
        // be misdecoded as typed characters.
        if second == 0x5B, start + 2 < buf.count, buf[start + 2] == 0x4D /* M */ {
            guard start + 6 <= buf.count else { return (nil, 0, true) }
            let cb = Int(buf[start + 3]) - 32
            let column = Int(buf[start + 4]) - 33   // 1-based → 0-based
            let row = Int(buf[start + 5]) - 33
            // X10 encodes a release as button code 3, without saying which
            // button; report it as the primary button.
            let event = mouseEvent(cb: cb, column: column, row: row, isRelease: (cb & 0b11) == 3)
            return (event, 6, false)
        }

        // Collect until a final byte in the range 0x40...0x7E.
        var j = start + 2
        while j < buf.count {
            let c = buf[j]
            if c >= 0x40 && c <= 0x7E {
                let params = Array(buf[(start + 2)..<j])
                let final = c
                let consumed = j - start + 1
                return (interpretCSI(final: final, params: params), consumed, false)
            }
            j += 1
        }
        // Final byte not yet received.
        return (nil, 0, true)
    }

    /// Maps a CSI/SS3 final byte (and any numeric parameters) to a ``KeyEvent``.
    private static func interpretCSI(final: UInt8, params: [UInt8]) -> KeyEvent? {
        // SGR mouse report: "ESC [ < cb ; cx ; cy M" (press/motion/wheel) or
        // "... m" (release), with 1-based coordinates.
        if params.first == 0x3C /* < */, final == 0x4D /* M */ || final == 0x6D /* m */ {
            let fields = String(decoding: params.dropFirst(), as: UTF8.self)
                .split(separator: ";")
                .compactMap { Int($0) }
            guard fields.count == 3 else { return nil }
            return mouseEvent(cb: fields[0], column: fields[1] - 1, row: fields[2] - 1, isRelease: final == 0x6D)
        }
        // Cursor-position report: "ESC [ row ; col R" (1-based), the answer
        // to a CSI 6n query. Both parameters must be present — a bare
        // "ESC [ R" (some terminals' F3) is not a report. A parametrised
        // "ESC [ 1;2R" is indistinguishable from Shift-F3 on rxvt-family
        // terminals; it is decoded as a position report and silently ignored
        // by resolveInlineOrigin when no cursor query is outstanding, so
        // Shift-F3 will not arrive as a key event on those terminals.
        if final == 0x52 /* R */ {
            let fields = String(decoding: params, as: UTF8.self)
                .split(separator: ";")
                .compactMap { Int($0) }
            guard fields.count == 2 else { return nil }
            return .cursorPosition(row: fields[0] - 1, column: fields[1] - 1)
        }
        switch final {
        case 0x41: return .up        // A
        case 0x42: return .down      // B
        case 0x43: return .right     // C
        case 0x44: return .left      // D
        case 0x48: return .home      // H
        case 0x46: return .end       // F
        case 0x5A: return .backTab   // Z (Shift-Tab)
        case 0x7E: // '~' — numbered key: parameter selects which.
            switch String(decoding: params, as: UTF8.self) {
            case "1", "7": return .home
            case "4", "8": return .end
            case "3":      return .delete
            default:       return nil
            }
        default:
            return nil
        }
    }

    /// Builds a ``KeyEvent/mouse(_:)`` from a decoded button code and 0-based
    /// position, or `nil` for reports SwiftLI doesn't act on.
    ///
    /// The button code packs the button in bits 0–1, modifiers in bits 2–4
    /// (ignored), motion in bit 5, and the wheel in bit 6.
    private static func mouseEvent(cb: Int, column: Int, row: Int, isRelease: Bool) -> KeyEvent? {
        guard column >= 0, row >= 0 else { return nil }
        let kind: MouseEvent.Kind
        if cb & 64 != 0 {
            // Wheel/swipe: 64=up, 65=down, 66=left, 67=right.
            switch cb & 0b11 {
            case 0: kind = .scrollUp
            case 1: kind = .scrollDown
            case 2: kind = .scrollLeft
            case 3: kind = .scrollRight
            default: return nil
            }
        } else {
            let button: MouseEvent.Button?
            switch cb & 0b11 {
            case 0: button = .left
            case 1: button = .middle
            case 2: button = .right
            default: button = nil   // 3 = "no button" (X10 release / motion)
            }
            if cb & 32 != 0 {
                // Motion while tracking: a drag with a button, else a move.
                kind = button.map { .drag($0) } ?? .move
            } else if isRelease {
                kind = .release(button ?? .left)
            } else if let button {
                kind = .press(button)
            } else {
                return nil
            }
        }
        return .mouse(MouseEvent(kind: kind, column: column, row: row))
    }

    // MARK: - UTF-8

    /// Decodes a single UTF-8 scalar beginning at `start`.
    private static func parseUTF8(_ buf: [UInt8], from start: Int) -> (event: KeyEvent?, consumed: Int, needMore: Bool) {
        let lead = buf[start]
        let length: Int
        if lead < 0x80        { length = 1 }
        else if lead < 0xE0   { length = 2 }
        else if lead < 0xF0   { length = 3 }
        else                  { length = 4 }

        guard start + length <= buf.count else { return (nil, 0, true) }

        let slice = Array(buf[start..<(start + length)])
        let decoded = String(decoding: slice, as: UTF8.self)
        if let ch = decoded.first {
            return (.character(ch), length, false)
        }
        // Invalid byte — skip it.
        return (nil, 1, false)
    }
}
