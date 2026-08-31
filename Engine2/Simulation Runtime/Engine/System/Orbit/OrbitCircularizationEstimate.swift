import simd

/// Live ideal guidance and finite-burn risk for one circularization maneuver.
///
/// `targetVelocity` is absolute world-space velocity. `deltaVelocity` is the
/// remaining ideal change needed to reach it. Fuel and duration values expose
/// the current maneuver margin without promising that a finite burn can attain
/// the instantaneous ideal exactly.
nonisolated struct OrbitCircularizationEstimate: Equatable, Sendable {
    let availableDeltaV: Double
    let deltaVelocity: SIMD3<Double>
    let deltaV: Double
    let deltaVMargin: Double
    let direction: COrbitCircularizationAutopilot.Direction
    let hasSufficientFuel: Bool
    let localOrbitalPeriod: Double
    let minimumBurnDuration: Double
    let requiredFuel: Double
    let targetVelocity: SIMD3<Double>

    /// Fraction of current ideal delta-v capacity left after the maneuver.
    var deltaVReserveFraction: Double {
        guard availableDeltaV > 0 else {
            return deltaV == 0 ? 1 : 0
        }
        return min(max(deltaVMargin / availableDeltaV, 0), 1)
    }

    /// Minimum burn duration as a fraction of the local circular period.
    var minimumBurnOrbitFraction: Double {
        minimumBurnDuration / localOrbitalPeriod
    }
}
