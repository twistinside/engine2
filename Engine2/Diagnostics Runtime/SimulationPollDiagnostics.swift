/// Completed cadence and backlog facts for one Simulation Runtime poll.
struct SimulationPollDiagnostics: Codable, Equatable, Sendable {
    let completedTick: SimulationTick
    let sampledWallDeltaNanoseconds: UInt64
    let stepsCompleted: Int
    let backlogBeforeNanoseconds: UInt64
    let backlogAfterNanoseconds: UInt64
    let durationNanoseconds: UInt64
}
