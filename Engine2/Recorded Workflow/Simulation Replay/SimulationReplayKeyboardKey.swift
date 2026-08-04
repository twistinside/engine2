/// Persistence-owned keyboard identity retained by a recorded Input snapshot.
nonisolated struct SimulationReplayKeyboardKey: Equatable, Hashable, Sendable {
    let keyCode: UInt16
    let displayName: String

    var inputValue: KeyboardKey {
        KeyboardKey(keyCode: keyCode, displayName: displayName)
    }

    init(keyCode: UInt16, displayName: String) {
        self.keyCode = keyCode
        self.displayName = displayName
    }

    init(recording key: KeyboardKey) {
        self.init(keyCode: key.keyCode, displayName: key.displayName)
    }
}

extension SimulationReplayKeyboardKey: Comparable {
    static func < (lhs: SimulationReplayKeyboardKey, rhs: SimulationReplayKeyboardKey) -> Bool {
        if lhs.displayName == rhs.displayName {
            lhs.keyCode < rhs.keyCode
        } else {
            lhs.displayName < rhs.displayName
        }
    }
}

extension SimulationReplayKeyboardKey: Codable {
    private enum CodingKeys: String, CodingKey {
        case displayName
        case keyCode
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            keyCode: try container.decode(UInt16.self, forKey: .keyCode),
            displayName: try container.decode(String.self, forKey: .displayName)
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(keyCode, forKey: .keyCode)
    }
}
