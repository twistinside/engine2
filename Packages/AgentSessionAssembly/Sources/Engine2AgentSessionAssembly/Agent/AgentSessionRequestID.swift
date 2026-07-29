import Engine2
import Engine2AssemblySupport
import Engine2OfflineCaptureAssembly
/// Exact idempotency identity for one request in one agent session.
///
/// Session qualification prevents a retry from another assembly instance from
/// colliding with this live process's monotonic request history.
public nonisolated struct AgentSessionRequestID: Codable, Hashable, Sendable {
    public let sessionID: AgentSessionID
    public let sequence: AgentSessionRequestSequence

    public init(
        sessionID: AgentSessionID,
        sequence: AgentSessionRequestSequence
    ) {
        self.sessionID = sessionID
        self.sequence = sequence
    }
}
