/// Identity of a completed fixed Simulation Runtime step.
///
/// A tick identifies simulation progress without carrying wall-clock or render
/// cadence assumptions. Tick zero describes a newly constructed world before
/// its first fixed step has completed.
nonisolated struct SimulationTick: Codable, Comparable, Hashable, Sendable {
    static let zero = SimulationTick(rawValue: 0)

    let rawValue: UInt64

    static func < (lhs: SimulationTick, rhs: SimulationTick) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Returns the identity of the next completed fixed step.
    func advanced() -> SimulationTick {
        precondition(rawValue < .max, "Simulation tick identity overflowed.")
        return SimulationTick(rawValue: rawValue + 1)
    }
}
