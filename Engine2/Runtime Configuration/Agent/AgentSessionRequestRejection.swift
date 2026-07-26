/// Non-consuming refusal plus the coordinator's best exact cursor knowledge.
nonisolated struct AgentSessionRequestRejection: Equatable, Sendable {
    let reason: AgentSessionRequestRejectionReason
    let knownCursor: SimulationCursor
}
