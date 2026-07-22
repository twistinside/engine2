/// Number of complete fixed steps committed by one Simulation advance.
///
/// Unlike a requested step count, zero is meaningful when no requested work
/// commits before an interruption or rejection is observed.
nonisolated struct SimulationCompletedStepCount: Hashable, Sendable {
    static let zero = SimulationCompletedStepCount(rawValue: 0)

    let rawValue: UInt32
}
