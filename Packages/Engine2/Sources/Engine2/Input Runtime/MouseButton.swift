/// Platform-neutral mouse button identity.
public nonisolated enum MouseButton: Hashable, Sendable {
    case left
    case right
    case middle
    case other(Int)

    public var displayName: String {
        switch self {
        case .left: "LMB"
        case .right: "RMB"
        case .middle: "MMB"
        case let .other(buttonNumber): "M\(buttonNumber)"
        }
    }
}

extension MouseButton: Comparable {
    private var sortIndex: Int {
        switch self {
        case .left: 0
        case .right: 1
        case .middle: 2
        case let .other(buttonNumber): 10 + buttonNumber
        }
    }

    public static func < (lhs: MouseButton, rhs: MouseButton) -> Bool {
        lhs.sortIndex < rhs.sortIndex
    }
}
