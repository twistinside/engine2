/// Exact, cursor-aware command to advance one Simulation Runtime session.
///
/// An expected cursor enables optimistic rejection of stale callers. Omitting
/// it deliberately accepts whichever cursor is current when the request wins
/// the Runtime's non-reentrant advance gate.
nonisolated struct SimulationAdvanceRequest: Sendable {
    let expectedCursor: SimulationCursor?
    let stepCount: SimulationStepCount
    let inputAssignment: SimulationInputAssignment

    init(
        expectedCursor: SimulationCursor? = nil,
        stepCount: SimulationStepCount,
        inputAssignment: SimulationInputAssignment = .none
    ) {
        self.expectedCursor = expectedCursor
        self.stepCount = stepCount
        self.inputAssignment = inputAssignment
    }
}
