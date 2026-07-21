/// Completed timing and schedule facts for one invariant system update.
struct SystemUpdateDiagnostics: Codable, Equatable, Sendable {
    let tick: SimulationTick
    let systemID: SimulationSystemID
    let scheduleLane: SimulationScheduleLane
    let executionOrder: Int
    let durationNanoseconds: UInt64
    let workCount: Int?
}
