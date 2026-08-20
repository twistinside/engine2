/// Selects whether one body emits gravity, responds to gravity, or does both.
///
/// Prescribed rail bodies normally use ``sourceOnly``. Integrated massive
/// bodies use ``sourceAndReceiver``, while test particles use ``receiverOnly``.
nonisolated enum GravityParticipation: UInt8, Codable, Equatable, Hashable, Sendable {
    case none = 0
    case sourceOnly = 1
    case receiverOnly = 2
    case sourceAndReceiver = 3

    /// Whether this body contributes its mass to other receivers.
    var isSource: Bool {
        switch self {
        case .none, .receiverOnly:
            false
        case .sourceOnly, .sourceAndReceiver:
            true
        }
    }

    /// Whether numerical propagation may apply gravity to this body.
    var isReceiver: Bool {
        switch self {
        case .none, .sourceOnly:
            false
        case .receiverOnly, .sourceAndReceiver:
            true
        }
    }
}
