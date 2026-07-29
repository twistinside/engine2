import Engine2
import Engine2AssemblySupport
import Engine2OfflineCaptureAssembly
/// One inseparable request and terminal response retained for exact replay.
///
/// Construction verifies that both values describe the same request identity
/// and caches the immutable response's named image-byte footprint. Replay
/// payload, response, and budget accounting therefore cannot drift.
nonisolated struct AgentSessionReplayEntry: Equatable, Sendable {
    let request: AgentCaptureRequest
    let response: AgentSessionResponse
    /// Exact named-budget footprint computed once with the immutable response.
    let retainedImageByteCount: Int

    var requestID: AgentSessionRequestID {
        request.id
    }

    /// Pairs one accepted request with the terminal response produced for it.
    init(request: AgentCaptureRequest, response: AgentSessionResponse) {
        precondition(request.id == response.requestID, "A replay entry must pair one request identity with its response.")

        self.request = request
        self.response = response
        self.retainedImageByteCount = response.outcome.retainedImageByteCount
    }
}
