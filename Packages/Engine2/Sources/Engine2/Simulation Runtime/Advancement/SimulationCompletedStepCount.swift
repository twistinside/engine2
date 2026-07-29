/// Number of complete fixed steps committed by one Simulation advance.
///
/// Current completed results are positive. Zero is reserved so a future
/// interrupted outcome can report that no requested work committed without
/// weakening the strictly positive request-count contract.
public nonisolated struct SimulationCompletedStepCount: Hashable, RawRepresentable, Sendable {
    public static let zero = SimulationCompletedStepCount(rawValue: 0)

    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
}
