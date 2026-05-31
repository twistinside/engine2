//
//  SMovement.swift
//  Engine2
//
//  Created by Karl Groff on 3/8/26.
//

import OSLog

/// Applies one frame of accumulated motion by first updating velocity and then
/// advancing position from the new velocity.
class SMovement: System {
    private static let signposter = OSSignposter(
        subsystem: "Engine2",
        category: "SMovement"
    )

    func update(world: inout World, deltaTime: Float) {
        let signpostState = Self.signposter.beginInterval("SMovement.update")
        defer {
            Self.signposter.endInterval("SMovement.update", signpostState)
        }

        // Drive iteration from the motion store and skip incomplete transform rows.
        let entities = world.motionComponents.entities

        for entity in entities {
            print("Processing movement for \(entity)")

            guard let position = world.positionComponents[entity] else {
                continue
            }
            print("Positions is \(position.position)")

            var updatedPosition: SIMD3<Float>?
            world.motionComponents.update(for: entity) { motion in
                print("Velocity is \(motion.velocity)")
                print("Accumulator is \(motion.accumulator)")

                // Continuous acceleration scales with `deltaTime`; impulse is an immediate
                // velocity delta. Position then advances using the updated velocity.
                let updatedVelocity = motion.velocity + motion.acceleration * deltaTime + motion.impulse
                let newPosition = position.position + updatedVelocity * deltaTime
                updatedPosition = newPosition

                print("Updated position is \(newPosition)")
                print("Velocity is \(updatedVelocity)")

                motion.velocity = updatedVelocity
                motion.accumulator = .zero
            }

            guard let updatedPosition else {
                continue
            }

            world.positionComponents.update(for: entity) { position in
                position.position = updatedPosition
            }

            // Motion contributions are per-frame inputs, so clear the accumulator
            // after they have been consumed.
            print("Clearing motion accumulator for \(entity)")
        }
    }
}
