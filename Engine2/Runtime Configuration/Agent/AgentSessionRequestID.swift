/// Exact idempotency identity for one request in one agent session.
///
/// Session qualification prevents a retry from another assembly instance from
/// colliding with this live process's monotonic request history.
nonisolated struct AgentSessionRequestID: Codable, Hashable, Sendable {
    let sessionID: AgentSessionID
    let sequence: AgentSessionRequestSequence
}
