/// Strictly positive number of complete fixed steps requested from Simulation.
///
/// Reading state without advancing belongs to a separate observation
/// capability, so zero is intentionally not a valid request count.
nonisolated struct SimulationStepCount: Hashable, Sendable {
    static let one = SimulationStepCount(rawValue: 1)

    let rawValue: UInt32

    init(rawValue: UInt32) {
        precondition(rawValue > 0, "A Simulation advance must request at least one step.")
        self.rawValue = rawValue
    }
}
