import simd

/// Instantaneous circularization result derived from current authoritative state.
///
/// `targetVelocity` is absolute world-space velocity. `deltaVelocity` is the
/// impulse required to reach it, and `requiredFuel` is the all-or-nothing
/// propellant mass implied by the ideal rocket equation.
nonisolated struct OrbitCircularizationEstimate: Equatable, Sendable {
    let deltaVelocity: SIMD3<Double>
    let targetVelocity: SIMD3<Double>
    let deltaV: Double
    let requiredFuel: Double
    let hasSufficientFuel: Bool
}
