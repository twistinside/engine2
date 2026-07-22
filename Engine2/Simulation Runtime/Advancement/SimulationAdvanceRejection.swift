/// Reason an exact Simulation advance was refused before mutating the world.
nonisolated enum SimulationAdvanceRejection: Equatable, Sendable {
    /// The caller expected a different committed position from the Runtime's
    /// current session-qualified cursor.
    case cursorMismatch(expected: SimulationCursor, current: SimulationCursor)

    /// The legacy real-time polling loop already owns advancement for this
    /// Runtime. A configuration must stop that authority before issuing an
    /// exact directed request.
    case advanceAuthorityActive(current: SimulationCursor)
}
