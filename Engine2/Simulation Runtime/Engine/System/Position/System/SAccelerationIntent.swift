//
//  SAccelerationIntent.swift
//  Engine2
//
//  Created by Codex on 5/31/26.
//

/// Emits persistent acceleration intent into the per-frame motion accumulator.
///
/// This keeps long-lived decisions such as "keep thrusting forward" separate
/// from the transient accumulator fields consumed and cleared by `SMovement`.
struct SAccelerationIntent: PSystem {
    mutating func update(world: inout World, deltaTime: Float) {
        let entities = world.motionComponents.entities

        for entity in entities {
            world.motionComponents.update(for: entity) { motion in
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
