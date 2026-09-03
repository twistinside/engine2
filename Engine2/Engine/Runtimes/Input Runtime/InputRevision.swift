/// Monotonic identity for an immutable value published by `InputRuntime`.
///
/// A new session starts whenever the runtime is restarted. Sequence numbers
/// order publications within that session.
nonisolated struct InputRevision: Equatable, Sendable {
    let session: UInt64
    let sequence: UInt64

    static let initial = InputRevision(session: 0, sequence: 0)

    init(session: UInt64, sequence: UInt64) {
        self.session = session
        self.sequence = sequence
    }

    /// Creates an ``InputRevision`` with the next sequence number.
    ///
    /// - Precondition: `revision.sequence` must be less than `UInt64.max`.
    init(advancing revision: InputRevision) {
        precondition(revision.sequence < .max, "Input revision sequence exhausted")
        self.session = revision.session
        self.sequence = revision.sequence + 1
    }

    /// Creates an ``InputRevision`` for the next session with the sequence set to zero.
    ///
    /// - Precondition: `revision.session` must be less than `UInt64.max`.
    init(following revision: InputRevision) {
        precondition(revision.session < .max, "Input revision session exhausted")
        self.session = revision.session + 1
        self.sequence = 0
    }
}

extension InputRevision: Comparable {
    /// Orders revisions by session, then by sequence within the same session.
    static func < (lhs: InputRevision, rhs: InputRevision) -> Bool {
        if lhs.session == rhs.session {
            lhs.sequence < rhs.sequence
        } else {
            lhs.session < rhs.session
        }
    }
}
