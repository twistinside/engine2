import Engine2
import Engine2AssemblySupport
import Engine2OfflineCaptureAssembly
/// Correlated terminal response for one accepted agent request identity.
public nonisolated struct AgentSessionResponse: Equatable, Sendable {
    public let requestID: AgentSessionRequestID
    public let outcome: AgentSessionExecutionOutcome
    /// Best exact authoritative cursor known after this terminal operation.
    public let knownCursor: SimulationCursor

    public init(
        requestID: AgentSessionRequestID,
        outcome: AgentSessionExecutionOutcome,
        knownCursor: SimulationCursor
    ) {
        self.requestID = requestID
        self.outcome = outcome
        self.knownCursor = knownCursor
    }
}
