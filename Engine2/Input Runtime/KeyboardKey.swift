/// Stable keyboard key identity for raw input state and debug display.
///
/// Keyboard layouts expose an open-ended display vocabulary, so the label is
/// retained as a string alongside the stable platform key code.
nonisolated struct KeyboardKey: Hashable, Comparable, Sendable {
    let keyCode: UInt16
    let displayName: String

    static func < (lhs: KeyboardKey, rhs: KeyboardKey) -> Bool {
        if lhs.displayName == rhs.displayName {
            lhs.keyCode < rhs.keyCode
        } else {
            lhs.displayName < rhs.displayName
        }
    }

    static func make(
        keyCode: UInt16,
        charactersIgnoringModifiers: String?
    ) -> KeyboardKey {
        KeyboardKey(
            keyCode: keyCode,
            displayName: displayName(
                for: keyCode,
                charactersIgnoringModifiers: charactersIgnoringModifiers
            )
        )
    }

    private static func displayName(
        for keyCode: UInt16,
        charactersIgnoringModifiers: String?
    ) -> String {
        switch keyCode {
        case 36: "Return"
        case 48: "Tab"
        case 49: "Space"
        case 51: "Delete"
        case 53: "Escape"
        case 123: "Left"
        case 124: "Right"
        case 125: "Down"
        case 126: "Up"
        default:
            if let character = charactersIgnoringModifiers?.first {
                String(character).uppercased()
            } else {
                "Key\(keyCode)"
            }
        }
    }
}
