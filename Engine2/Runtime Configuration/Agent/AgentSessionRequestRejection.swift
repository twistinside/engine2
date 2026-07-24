/// Non-consuming refusal plus the coordinator's best exact cursor knowledge.
nonisolated struct AgentSessionRequestRejection: Equatable, Sendable {
    let reason: AgentSessionRequestRejectionReason
    let knownCursor: SimulationCursor

    /// Captures a stable reason without discarding authoritative position.
    init(
        reason: AgentSessionRequestRejectionReason,
        knownCursor: SimulationCursor
    ) {
        self.reason = reason
        self.knownCursor = knownCursor
    }
}
