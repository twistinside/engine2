import Foundation
import simd

/// Analytic circular-orbit state for one deterministic rail entity.
///
/// `elapsedTime` is the only advancing state. `OrbitalRailSystem` derives position
/// and velocity from the complete phase each tick, so integration error cannot
/// accumulate in the rail trajectory.
struct OrbitalRailComponent: Component {
    let angularSpeed: Double
    let phase: Double
    let primaryEntityID: EntityID
    let radius: Double
    var elapsedTime: Double
    var velocity: SIMD3<Double>

    init(
        primaryEntityID: EntityID,
        radius: Double,
        angularSpeed: Double,
        phase: Double,
        elapsedTime: Double = 0,
        velocity: SIMD3<Double> = .zero
    ) {
        precondition(radius.isFinite && radius > 0, "An orbital rail radius must be finite and positive.")
        precondition(angularSpeed.isFinite, "An orbital rail angular speed must be finite.")
        precondition(phase.isFinite, "An orbital rail phase must be finite.")
        precondition(elapsedTime.isFinite && elapsedTime >= 0, "Orbital rail elapsed time must be finite and nonnegative.")
        precondition(velocity.isFinite, "Orbital rail velocity must be finite.")

        self.primaryEntityID = primaryEntityID
        self.radius = radius
        self.angularSpeed = angularSpeed
        self.phase = phase
        self.elapsedTime = elapsedTime
        self.velocity = velocity
    }

    /// Returns the exact planar position and velocity for the current phase.
    func state(relativeTo primaryPosition: SIMD3<Double>) -> (position: SIMD3<Double>, velocity: SIMD3<Double>) {
        let angle = phase + angularSpeed * elapsedTime
        let cosine = cos(angle)
        let sine = sin(angle)
        let radialOffset = SIMD3<Double>(radius * cosine, radius * sine, 0)
        let tangentialVelocity = SIMD3<Double>(
            -radius * angularSpeed * sine,
            radius * angularSpeed * cosine,
            0
        )
        return (primaryPosition + radialOffset, tangentialVelocity)
    }
}
