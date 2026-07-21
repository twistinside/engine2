/// Completed timing and state facts for one fixed Simulation Runtime step.
struct SimulationStepDiagnostics: Codable, Equatable, Sendable {
    let tick: SimulationTick
    let didRunSimulationSystems: Bool
    let durationNanoseconds: UInt64
}
