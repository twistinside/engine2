import simd

/// Adds collective Newtonian source acceleration to explicit receivers.
///
/// The system contributes to `MotionComponent.accumulator` and leaves integration and
/// accumulator cleanup to `MovementSystem`. Sources and receivers remain separate
/// capabilities, so deterministic rail bodies do not become dynamic merely by
/// orbiting the same star.
struct GravitySystem: System {
    mutating func update(world: inout World, deltaTime _: Double) {
        let receivers = world.components[GravityReceiverComponent.self].entities
        let sources = world.components[GravitySourceComponent.self].entities

        for receiver in receivers {
            guard let receiverPosition = world.components[PositionComponent.self][receiver]?.position,
                  world.components[MotionComponent.self][receiver] != nil else {
                continue
            }

            var acceleration = SIMD3<Double>.zero
            for source in sources where source != receiver {
                guard let sourcePosition = world.components[PositionComponent.self][source]?.position,
                      let sourceComponent = world.components[GravitySourceComponent.self][source] else {
                    continue
                }

                let offset = sourcePosition - receiverPosition
                let distanceSquared = simd_length_squared(offset)
                guard offset.isFinite,
                      distanceSquared.isFinite,
                      distanceSquared > 0 else {
                    continue
                }

                let distance = distanceSquared.squareRoot()
                let contribution = offset * (sourceComponent.gravitationalParameter / (distanceSquared * distance))
                guard contribution.isFinite else {
                    continue
                }
                acceleration += contribution
            }

            guard acceleration.isFinite else {
                continue
            }
            world.components[MotionComponent.self].update(for: receiver) { motion in
                motion.accumulator.acceleration += acceleration
            }
        }
    }
}
