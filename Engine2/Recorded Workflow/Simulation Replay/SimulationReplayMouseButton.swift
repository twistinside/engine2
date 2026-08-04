/// Stable persistence vocabulary for every platform-neutral mouse button.
nonisolated enum SimulationReplayMouseButton: Equatable, Hashable, Sendable {
    case left
    case right
    case middle
    case other(Int)

    var inputValue: MouseButton {
        switch self {
        case .left:
            .left
        case .right:
            .right
        case .middle:
            .middle
        case let .other(buttonNumber):
            .other(buttonNumber)
        }
    }

    init(recording button: MouseButton) {
        self = switch button {
        case .left:
            .left
        case .right:
            .right
        case .middle:
            .middle
        case let .other(buttonNumber):
            .other(buttonNumber)
        }
    }
}

extension SimulationReplayMouseButton: Comparable {
    static func < (lhs: SimulationReplayMouseButton, rhs: SimulationReplayMouseButton) -> Bool {
        switch (lhs, rhs) {
        case (.left, .left), (.right, .right), (.middle, .middle):
            false
        case (.left, _):
            true
        case (_, .left):
            false
        case (.right, _):
            true
        case (_, .right):
            false
        case (.middle, _):
            true
        case (_, .middle):
            false
        case let (.other(lhsNumber), .other(rhsNumber)):
            lhsNumber < rhsNumber
        }
    }
}

extension SimulationReplayMouseButton: Codable {
    private enum CodingKeys: String, CodingKey {
        case buttonNumber
        case kind
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)

        self = switch kind {
        case .left:
            .left
        case .right:
            .right
        case .middle:
            .middle
        case .other:
            .other(
                try container.decode(Int.self, forKey: .buttonNumber)
            )
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .left:
            try container.encode(Kind.left, forKey: .kind)
        case .right:
            try container.encode(Kind.right, forKey: .kind)
        case .middle:
            try container.encode(Kind.middle, forKey: .kind)
        case let .other(buttonNumber):
            try container.encode(Kind.other, forKey: .kind)
            try container.encode(buttonNumber, forKey: .buttonNumber)
        }
    }

    private enum Kind: String, Codable {
        case left
        case right
        case middle
        case other
    }
}
