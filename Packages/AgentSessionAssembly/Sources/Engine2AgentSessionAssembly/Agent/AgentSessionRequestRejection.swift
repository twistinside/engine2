import Engine2
import Engine2AssemblySupport
import Engine2OfflineCaptureAssembly
/// Non-consuming refusal plus the coordinator's best exact cursor knowledge.
public nonisolated struct AgentSessionRequestRejection: Equatable, Sendable {
    public let reason: AgentSessionRequestRejectionReason
    public let knownCursor: SimulationCursor

    public init(
        reason: AgentSessionRequestRejectionReason,
        knownCursor: SimulationCursor
    ) {
        self.reason = reason
        self.knownCursor = knownCursor
    }
}
