/// Narrow transport-neutral capability for idempotent agent capture requests.
///
/// A future MCP adapter may serialize calls into this boundary without gaining
/// access to Simulation, Render, or either lower-level offline capture method.
nonisolated protocol PAgentSessionTarget: AnyObject, Sendable {
    func capture(
        _ request: AgentCaptureRequest
    ) async -> AgentSessionSubmissionOutcome
}
