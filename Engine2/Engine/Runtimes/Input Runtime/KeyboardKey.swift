/// Stable keyboard key identity received through physical input ingress.
nonisolated struct KeyboardKey: Hashable, Sendable {
    let keyCode: UInt16
}
