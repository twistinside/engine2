/// Exact, cursor-aware command to advance one Simulation Runtime session.
///
/// An expected cursor enables optimistic rejection of stale callers. A caller
/// that explicitly supplies `nil` deliberately accepts whichever cursor is
/// current when the request wins the Runtime's non-reentrant advance gate. The
/// optional maneuver remains attributable to that same exact request.
nonisolated struct SimulationAdvanceRequest: Sendable {
    let expectedCursor: SimulationCursor?
    let stepCount: SimulationStepCount
    let inputAssignment: SimulationInputAssignment
    let orbitCircularizationCommand: OrbitCircularizationCommand?

    init(
        expectedCursor: SimulationCursor?,
        stepCount: SimulationStepCount,
        inputAssignment: SimulationInputAssignment,
        orbitCircularizationCommand: OrbitCircularizationCommand? = nil
    ) {
        self.expectedCursor = expectedCursor
        self.stepCount = stepCount
        self.inputAssignment = inputAssignment
        self.orbitCircularizationCommand = orbitCircularizationCommand
    }
}
