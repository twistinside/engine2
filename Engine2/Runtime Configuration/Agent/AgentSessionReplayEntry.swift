/// One inseparable request and terminal response retained for exact replay.
///
/// Construction verifies that both values describe the same request identity,
/// preventing replay payload and response storage from drifting independently.
nonisolated struct AgentSessionReplayEntry: Equatable, Sendable {
    let request: AgentCaptureRequest
    let response: AgentSessionResponse

    /// Pairs one accepted request with the terminal response produced for it.
    init(request: AgentCaptureRequest, response: AgentSessionResponse) {
        precondition(request.id == response.requestID, "A replay entry must pair one request identity with its response.")

        self.request = request
        self.response = response
    }

    var requestID: AgentSessionRequestID {
        request.id
    }
}
