/// Exact, cursor-aware command to advance one Simulation Runtime session.
///
/// An expected cursor enables optimistic rejection of stale callers. A caller
/// that explicitly supplies `nil` deliberately accepts whichever cursor is
/// current when the request wins the Runtime's non-reentrant advance gate.
public nonisolated struct SimulationAdvanceRequest: Sendable {
    public let expectedCursor: SimulationCursor?
    public let stepCount: SimulationStepCount
    public let inputAssignment: SimulationInputAssignment

    public init(
        expectedCursor: SimulationCursor?,
        stepCount: SimulationStepCount,
        inputAssignment: SimulationInputAssignment
    ) {
        self.expectedCursor = expectedCursor
        self.stepCount = stepCount
        self.inputAssignment = inputAssignment
    }
}
