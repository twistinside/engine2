/// Identity of a completed fixed Simulation Runtime step.
///
/// A tick identifies simulation progress without carrying wall-clock or render
/// cadence assumptions. Tick zero describes a newly constructed world before
/// its first fixed step has completed.
public nonisolated struct SimulationTick: Codable, Hashable, RawRepresentable, Sendable {
    public static let zero = SimulationTick(rawValue: 0)

    public let rawValue: UInt64

    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    /// Returns the identity of the next completed fixed step.
    public func advanced() -> SimulationTick {
        precondition(rawValue < .max, "Simulation tick identity overflowed.")
        return SimulationTick(rawValue: rawValue + 1)
    }
}

extension SimulationTick: Comparable {
    public static func < (lhs: SimulationTick, rhs: SimulationTick) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
