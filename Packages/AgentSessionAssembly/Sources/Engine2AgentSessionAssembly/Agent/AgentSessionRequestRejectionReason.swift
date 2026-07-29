import Engine2
import Engine2AssemblySupport
import Engine2OfflineCaptureAssembly
/// Closed reasons a request was refused without consuming its supplied identity.
///
/// New-work admission throws this value inside the coordinator. The protocol
/// boundary converts it into ``AgentSessionRequestRejection`` so refusal remains
/// replayable contract data rather than escaping as an implementation error.
public nonisolated enum AgentSessionRequestRejectionReason: Error, Equatable, Sendable {
    case wrongSession(expected: AgentSessionID, actual: AgentSessionID)
    /// The payload cannot participate in stable equality, such as a viewpoint
    /// containing NaN camera state, so accepting it would make exact retry
    /// comparison non-reflexive.
    case invalidPayload
    case unexpectedSequence(expected: AgentSessionRequestSequence, actual: AgentSessionRequestSequence)
    case requestConflict(AgentSessionRequestID)
    case anotherRequestBusy(activeRequestID: AgentSessionRequestID)
    case resultEvicted(AgentSessionRequestID)
    case cancelledBeforeAcceptance
    case sessionClosed
}
