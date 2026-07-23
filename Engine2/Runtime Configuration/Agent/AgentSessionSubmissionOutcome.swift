/// Complete admission or replay outcome for one agent request submission.
nonisolated enum AgentSessionSubmissionOutcome: Equatable, Sendable {
    /// This call accepted the identity and produced its terminal response.
    case executed(AgentSessionResponse)

    /// A retained identical request returned its original terminal response.
    case replayed(AgentSessionResponse)

    /// The identical accepted identity is still executing and cannot be joined.
    case requestInProgress(
        requestID: AgentSessionRequestID,
        knownCursor: SimulationCursor
    )

    /// The supplied identity was not consumed.
    case rejected(AgentSessionRequestRejection)
}
