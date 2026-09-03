/// Number of complete fixed steps committed by one Simulation advance.
///
/// Current completed results are positive. Zero is reserved so a future
/// interrupted outcome can report that no requested work committed without
/// weakening the strictly positive request-count contract.
nonisolated struct SimulationCompletedStepCount: Hashable, RawRepresentable, Sendable {
    static let zero = SimulationCompletedStepCount(rawValue: 0)

    let rawValue: UInt32

    init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
}
