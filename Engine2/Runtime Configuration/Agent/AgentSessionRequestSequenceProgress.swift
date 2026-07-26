/// Value-semantic admission progress for one agent session's monotonic request lane.
///
/// The private states keep accepted high-water coupled to the next expected
/// sequence. Exhaustion preserves the final accepted sequence even though no
/// representable successor exists, while a newly constructed value has no
/// accepted high-water at all.
nonisolated struct AgentSessionRequestSequenceProgress: Equatable, Sendable {
    /// Relationship between one candidate and the session's accepted progress.
    enum Classification: Equatable, Sendable {
        case expected
        case atOrBelowAcceptedHighWater
        case unexpected(expected: AgentSessionRequestSequence)
    }

    private enum State: Equatable, Sendable {
        case initial(expected: AgentSessionRequestSequence)
        case awaitingNext(expected: AgentSessionRequestSequence, highestAccepted: AgentSessionRequestSequence)
        case exhausted(highestAccepted: AgentSessionRequestSequence)
    }

    private var state: State

    /// Starts a fresh or restored lane before its first accepted request.
    init(initialSequence: AgentSessionRequestSequence) {
        state = .initial(expected: initialSequence)
    }

    /// Whether the last accepted sequence has no representable successor.
    var isExhausted: Bool {
        if case .exhausted = state {
            true
        } else {
            false
        }
    }

    /// Classifies a candidate without consuming it or changing progress.
    func classification(of candidate: AgentSessionRequestSequence) -> Classification {
        switch state {
        case let .initial(expected):
            return candidate == expected
                ? Classification.expected
                : Classification.unexpected(expected: expected)

        case let .awaitingNext(expected, highestAccepted):
            if candidate <= highestAccepted {
                return .atOrBelowAcceptedHighWater
            } else if candidate == expected {
                return .expected
            } else {
                return .unexpected(expected: expected)
            }

        case let .exhausted(highestAccepted):
            precondition(candidate <= highestAccepted, "Exhausted agent sequence high-water must be UInt64.max.")
            return .atOrBelowAcceptedHighWater
        }
    }

    /// Consumes the exact expected sequence and advances high-water atomically.
    mutating func accept(_ sequence: AgentSessionRequestSequence) {
        guard classification(of: sequence) == .expected else {
            preconditionFailure("Agent sequence progress can accept only its exact expected sequence.")
        }

        if let successor = sequence.successor() {
            state = .awaitingNext(
                expected: successor,
                highestAccepted: sequence
            )
        } else {
            state = .exhausted(highestAccepted: sequence)
        }
    }
}
