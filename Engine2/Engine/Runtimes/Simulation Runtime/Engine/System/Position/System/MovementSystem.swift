import OSLog

/// Integrates one scheduled interval of accumulated translational motion with symplectic Euler.
///
/// The system updates velocity before position, then clears the interval-local
/// accumulator. Both authoritative values use double-precision SI units.
struct MovementSystem: System {
    private static let signposter = OSSignposter(
        subsystem: "Engine2",
        category: "MovementSystem"
    )

    mutating func update(world: inout World, deltaTime: Double) {
        let signpostState = Self.signposter.beginInterval("MovementSystem.update")
        defer {
            Self.signposter.endInterval("MovementSystem.update", signpostState)
        }

        // Drive iteration from the motion store and skip incomplete transform rows.
        let entities = world.components[MotionComponent.self].entities

        for entity in entities {
            guard let position = world.components[PositionComponent.self][entity] else {
                continue
            }

            var updatedPosition: SIMD3<Double>?
            world.components[MotionComponent.self].update(for: entity) { motion in
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

            world.components[PositionComponent.self].update(for: entity) { position in
                position.position = updatedPosition
            }
        }
    }
}
