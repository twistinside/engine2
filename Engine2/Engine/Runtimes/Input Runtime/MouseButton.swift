/// Platform-neutral mouse button identity.
nonisolated enum MouseButton: Hashable, Sendable {
    case left
    case right
    case middle
    case other(Int)
}
