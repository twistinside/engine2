//
//  SRotation.swift
//  Engine2
//
//  Created by Codex on 3/16/26.
//

import OSLog
import simd

/// Applies one frame of accumulated angular motion by first updating angular
/// velocity and then advancing orientation from the new angular velocity.
class SRotation: System {
    private static let signposter = OSSignposter(
        subsystem: "Engine2",
        category: "SRotation"
    )

    func update(world: inout World, deltaTime: Float) {
        let signpostState = Self.signposter.beginInterval("SRotation.update")
        defer {
            Self.signposter.endInterval("SRotation.update", signpostState)
        }

        // Most entities will have no explicit angular input this frame, so reuse
        // one zero-value accumulator instead of constructing a new default each iteration.
        let zeroAccumulator = CAngularMotionAccumulator(
            angularAcceleration: .zero,
            angularImpulse: .zero
        )

        // Drive iteration from the angular-velocity store and skip incomplete angular rows.
        let entities = world.angularVelocityComponents.entities

        for entity in entities {
            guard
                let rotation = world.rotationComponents[entity],
                let angularVelocity = world.angularVelocityComponents[entity]
            else {
                continue
            }

            let accumulator = world.angularMotionAccumulatorComponents[entity] ?? zeroAccumulator

            // Continuous angular acceleration scales with `deltaTime`; impulse is an
            // immediate angular velocity delta. Orientation then advances from the
            // updated angular velocity over this fixed step.
            let updatedAngularVelocity =
                angularVelocity.angularVelocity
                + accumulator.angularAcceleration * deltaTime
                + accumulator.angularImpulse
            let deltaRotation = Self.deltaRotation(
                for: updatedAngularVelocity,
                deltaTime: deltaTime
            )
            let updatedRotation = Self.normalized(deltaRotation * rotation.rotation)

            world.angularVelocityComponents.insert(
                CAngularVelocity(angularVelocity: updatedAngularVelocity),
                for: entity
            )
            world.rotationComponents.insert(CRotation(rotation: updatedRotation), for: entity)

            // Angular motion contributions are per-frame inputs, so clear the
            // accumulator after they have been consumed.
            if world.angularMotionAccumulatorComponents[entity] != nil {
                world.angularMotionAccumulatorComponents.insert(zeroAccumulator, for: entity)
            }
        }
    }

    /// Converts an axis-rate angular velocity into the quaternion delta for one step.
    private static func deltaRotation(
        for angularVelocity: SIMD3<Float>,
        deltaTime: Float
    ) -> simd_quatf {
        let angularStep = angularVelocity * deltaTime
        let angle = simd_length(angularStep)

        guard angle > 0 else {
            return simd_quatf(angle: 0, axis: SIMD3<Float>(0, 0, 1))
        }

        let axis = angularStep / angle
        return simd_quatf(angle: angle, axis: axis)
    }

    /// Renormalizes accumulated quaternion math back onto the unit sphere.
    private static func normalized(_ rotation: simd_quatf) -> simd_quatf {
        simd_quatf(vector: simd_normalize(rotation.vector))
    }
}
