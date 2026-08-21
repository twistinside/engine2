import OSLog
import simd

/// Applies one scheduled interval of accumulated angular motion by first updating angular
/// velocity and then advancing orientation from the new angular velocity.
struct SRotation: PSystem {
    private static let signposter = OSSignposter(
        subsystem: "Engine2",
        category: "SRotation"
    )

    mutating func update(world: inout World, deltaTime: Double) {
        let signpostState = Self.signposter.beginInterval("SRotation.update")
        defer {
            Self.signposter.endInterval("SRotation.update", signpostState)
        }

        // Most entities will have no explicit angular input for this invocation, so reuse
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
            // updated angular velocity over this invocation interval.
            let updatedAngularVelocity =
                angularVelocity.angularVelocity
                + accumulator.angularAcceleration * Float(deltaTime)
                + accumulator.angularImpulse
            let rotationDelta = deltaRotation(
                for: updatedAngularVelocity,
                deltaTime: Float(deltaTime)
            )
            let accumulatedRotation = rotationDelta * rotation.rotation
            let updatedRotation = simd_quatf(vector: simd_normalize(accumulatedRotation.vector))

            world.angularVelocityComponents.update(for: entity) { angularVelocity in
                angularVelocity = CAngularVelocity(angularVelocity: updatedAngularVelocity)
            }
            world.rotationComponents.update(for: entity) { rotation in
                rotation = CRotation(rotation: updatedRotation)
            }

            // Angular motion contributions are interval-local inputs, so clear the
            // accumulator after they have been consumed.
            world.angularMotionAccumulatorComponents.update(for: entity) { accumulator in
                accumulator = zeroAccumulator
            }
        }
    }

    /// Converts an axis-rate angular velocity into the quaternion delta for one step.
    private func deltaRotation(for angularVelocity: SIMD3<Float>, deltaTime: Float) -> simd_quatf {
        let angularStep = angularVelocity * deltaTime
        let angle = simd_length(angularStep)

        guard angle > 0 else {
            return .identity
        }

        let axis = angularStep / angle
        return simd_quatf(angle: angle, axis: axis)
    }
}
