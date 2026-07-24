/// Monotonic request position inside one ``AgentSessionID``.
///
/// A sequence is separate from bounded replay retention. Once accepted, an old
/// position can never become executable again merely because its result bytes
/// were evicted.
nonisolated struct AgentSessionRequestSequence:
    Codable,
    Comparable,
    Hashable,
    RawRepresentable,
    Sendable
{
    /// First request position accepted by a newly constructed session.
    static let first = AgentSessionRequestSequence(rawValue: 0)

    let rawValue: UInt64

    /// Creates an explicit request position, including restored high-water state.
    init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    /// Returns the next representable position, or `nil` at sequence exhaustion.
    func successor() -> AgentSessionRequestSequence? {
        guard rawValue < .max else {
            return nil
        }
        return AgentSessionRequestSequence(rawValue: rawValue + 1)
    }

    static func < (
        lhs: AgentSessionRequestSequence,
        rhs: AgentSessionRequestSequence
    ) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
