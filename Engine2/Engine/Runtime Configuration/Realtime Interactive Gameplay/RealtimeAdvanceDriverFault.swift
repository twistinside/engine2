/// Authority fault that prevents a real-time driver from continuing safely.
nonisolated enum RealtimeAdvanceDriverFault: Equatable, Sendable {
    /// The target was not at the cursor exclusively owned by the driver.
    case cursorMismatch(expected: SimulationCursor, current: SimulationCursor)
}
