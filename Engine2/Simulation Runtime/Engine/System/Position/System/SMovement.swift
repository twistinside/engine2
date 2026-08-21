import OSLog

/// Integrates one scheduled interval of accumulated translational motion with symplectic Euler.
///
/// The system updates velocity before position, then clears the interval-local
/// accumulator. Both authoritative values use double-precision SI units.
struct SMovement: PSystem {
    private static let signposter = OSSignposter(
        subsystem: "Engine2",
        category: "SMovement"
    )

    mutating func update(world: inout World, deltaTime: Double) {
        let signpostState = Self.signposter.beginInterval("SMovement.update")
        defer {
            Self.signposter.endInterval("SMovement.update", signpostState)
        }

        // Drive iteration from the motion store and skip incomplete transform rows.
        let entities = world.motionComponents.entities

        for entity in entities {
            guard let position = world.positionComponents[entity] else {
                continue
            }

            var updatedPosition: SIMD3<Double>?
            world.motionComponents.update(for: entity) { motion in
                // Continuous acceleration scales with `deltaTime`; impulse is an immediate
                // velocity delta. Position then advances using the updated velocity.
                let updatedVelocity = motion.velocity + motion.acceleration * deltaTime + motion.impulse
                let newPosition = position.position + updatedVelocity * deltaTime
                updatedPosition = newPosition

                motion.velocity = updatedVelocity
                motion.accumulator = .zero
            }

            guard let updatedPosition else {
                continue
            }

            world.positionComponents.update(for: entity) { position in
                position.position = updatedPosition
            }
        }
    }
}
