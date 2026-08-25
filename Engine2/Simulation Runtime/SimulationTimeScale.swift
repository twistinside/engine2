/// Positive finite ratio between authoritative world time and the nominal Simulation base interval.
///
/// The value scales the interval passed to Simulation systems without changing
/// request or cursor semantics, wall-clock polling, or presentation cadence.
/// Named values are authored fixture policy, not a player-facing time-control
/// surface.
nonisolated struct SimulationTimeScale: Equatable, Sendable {
    /// One world second per second of nominal Simulation base interval.
    static let realTime = Self(multiplier: 1)

    /// One simulated hour per 1/60-second tick for the Solar System smoke test.
    static let solarSystemSmokeTest = Self(multiplier: 216_000)

    let multiplier: Double

    init(multiplier: Double) {
        precondition(
            multiplier.isFinite && multiplier > 0,
            "Simulation time scale must be finite and positive."
        )
        self.multiplier = multiplier
    }
}
