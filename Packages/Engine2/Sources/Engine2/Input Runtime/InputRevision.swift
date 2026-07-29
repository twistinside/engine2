/// Monotonic identity for an immutable value published by `InputRuntime`.
///
/// A new session starts whenever the runtime is restarted. Sequence numbers
/// order publications within that session.
public nonisolated struct InputRevision: Equatable, Sendable {
    public let session: UInt64
    public let sequence: UInt64

    public static let initial = InputRevision(session: 0, sequence: 0)

    public init(session: UInt64, sequence: UInt64) {
        self.session = session
        self.sequence = sequence
    }

    public func advanced() -> InputRevision {
        precondition(sequence < .max, "Input revision sequence exhausted")
        return InputRevision(session: session, sequence: sequence + 1)
    }

    public func startingNextSession() -> InputRevision {
        precondition(session < .max, "Input revision session exhausted")
        return InputRevision(session: session + 1, sequence: 0)
    }
}

extension InputRevision: Comparable {
    public static func < (lhs: InputRevision, rhs: InputRevision) -> Bool {
        if lhs.session == rhs.session {
            lhs.sequence < rhs.sequence
        } else {
            lhs.session < rhs.session
        }
    }
}
