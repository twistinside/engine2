//
//  SMovement.swift
//  Engine2
//
//  Created by Karl Groff on 3/8/26.
//

/// Applies one frame of accumulated motion by first updating velocity and then
/// advancing position from the new velocity.
class SMovement: System {
    func update(world: inout World, deltaTime: Float) {
        // Most entities will have no explicit motion input this frame, so reuse
        // one zero-value accumulator instead of constructing a new default each iteration.
        let zeroAccumulator = CMotionAccumulator(acceleration: .zero, impulse: .zero)

        // Drive iteration from the position store and skip incomplete motion rows.
        let entities = world.positionComponents.entities

        for entity in entities {
            guard
                let position = world.positionComponents[entity],
                let velocity = world.velocityComponents[entity]
            else {
                continue
            }

            let accumulator = world.motionAccumulatorComponents[entity] ?? zeroAccumulator

            // Continuous acceleration scales with `deltaTime`; impulse is an immediate
            // velocity delta. Position then advances using the updated velocity.
            let updatedVelocity = velocity.velocity + accumulator.acceleration * deltaTime + accumulator.impulse
            let updatedPosition = position.position + updatedVelocity * deltaTime

            world.velocityComponents.insert(CVelocity(velocity: updatedVelocity), for: entity)
            world.positionComponents.insert(CPosition(position: updatedPosition), for: entity)

            // Motion contributions are per-frame inputs, so clear the accumulator
            // after they have been consumed.
            if world.motionAccumulatorComponents[entity] != nil {
                world.motionAccumulatorComponents.insert(zeroAccumulator, for: entity)
            }
        }
    }
}
