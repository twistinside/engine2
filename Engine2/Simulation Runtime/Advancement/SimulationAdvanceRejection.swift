/// Reason an exact Simulation advance was refused before mutating the world.
nonisolated enum SimulationAdvanceRejection: Equatable, Sendable {
    /// The caller expected a different committed position from the Runtime's
    /// current session-qualified cursor.
    case cursorMismatch(expected: SimulationCursor, current: SimulationCursor)
}
