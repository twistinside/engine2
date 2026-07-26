/// Correlated terminal response for one accepted agent request identity.
nonisolated struct AgentSessionResponse: Equatable, Sendable {
    let requestID: AgentSessionRequestID
    let outcome: AgentSessionExecutionOutcome
    /// Best exact authoritative cursor known after this terminal operation.
    let knownCursor: SimulationCursor
}
