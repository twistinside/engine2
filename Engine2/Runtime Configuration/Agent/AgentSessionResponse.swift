/// Correlated terminal response for one accepted agent request identity.
nonisolated struct AgentSessionResponse: Equatable, Sendable {
    let requestID: AgentSessionRequestID
    let outcome: AgentSessionExecutionOutcome

    /// Best exact authoritative cursor known after this terminal operation.
    let knownCursor: SimulationCursor

    /// Creates one replayable terminal response.
    init(
        requestID: AgentSessionRequestID,
        outcome: AgentSessionExecutionOutcome,
        knownCursor: SimulationCursor
    ) {
        self.requestID = requestID
        self.outcome = outcome
        self.knownCursor = knownCursor
    }
}
