/// Emits persistent acceleration intent into the interval-local motion accumulator.
///
/// This keeps long-lived decisions such as "keep thrusting forward" separate
/// from the transient accumulator fields consumed and cleared by `MovementSystem`.
struct AccelerationIntentSystem: System {
    mutating func update(world: inout World, deltaTime: Double) {
        let entities = world.components[MotionComponent.self].entities

        for entity in entities {
            world.components[MotionComponent.self].update(for: entity) { motion in
                switch motion.accelerationIntent {
                case .idle:
                    return

                case .accelerating(let acceleration):
                    motion.accumulator.acceleration += acceleration
                }
            }
        }
    }
}
