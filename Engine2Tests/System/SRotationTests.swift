//
//  SRotationTests.swift
//  Engine2Tests
//
//  Created by Codex on 3/16/26.
//

import Testing
import simd
@testable import Engine2

struct SRotationTests {
    @Test func integratesAngularVelocityAndClearsAccumulator() async throws {
        var world = World()
        let entity = EntityID(index: 0, generation: 0)

        world.rotationComponents.insert(
            CRotation(rotation: simd_quatf(angle: 0, axis: SIMD3<Float>(0, 0, 1))),
            for: entity
        )
        world.angularVelocityComponents.insert(
            CAngularVelocity(angularVelocity: SIMD3<Float>(0, 0, 1)),
            for: entity
        )
        world.angularMotionAccumulatorComponents.insert(
            CAngularMotionAccumulator(
                angularAcceleration: SIMD3<Float>(0, 0, 2),
                angularImpulse: SIMD3<Float>(0, 0, 0.5)
            ),
            for: entity
        )

        let system = SRotation()
        system.update(world: &world, deltaTime: 0.5)

        let expectedAngularVelocity = SIMD3<Float>(0, 0, 2.5)
        let expectedRotation = simd_quatf(angle: 1.25, axis: SIMD3<Float>(0, 0, 1))

        #expect(world.angularVelocityComponents[entity]?.angularVelocity == expectedAngularVelocity)
        #expect(quaternionVectorsApproximatelyEqual(
            world.rotationComponents[entity]?.rotation.vector,
            expectedRotation.vector
        ))
        #expect(world.angularMotionAccumulatorComponents[entity]?.angularAcceleration == .zero)
        #expect(world.angularMotionAccumulatorComponents[entity]?.angularImpulse == .zero)
    }

    @Test func integratesRotationWithoutAccumulatorComponent() async throws {
        var world = World()
        let entity = EntityID(index: 0, generation: 0)

        world.rotationComponents.insert(
            CRotation(rotation: simd_quatf(angle: .pi / 6, axis: SIMD3<Float>(0, 1, 0))),
            for: entity
        )
        world.angularVelocityComponents.insert(
            CAngularVelocity(angularVelocity: SIMD3<Float>(0, 2, 0)),
            for: entity
        )

        let system = SRotation()
        system.update(world: &world, deltaTime: 0.25)

        let expectedRotation = simd_quatf(angle: .pi / 6 + 0.5, axis: SIMD3<Float>(0, 1, 0))

        #expect(world.angularVelocityComponents[entity]?.angularVelocity == SIMD3<Float>(0, 2, 0))
        #expect(quaternionVectorsApproximatelyEqual(
            world.rotationComponents[entity]?.rotation.vector,
            expectedRotation.vector
        ))
        #expect(world.angularMotionAccumulatorComponents[entity] == nil)
    }
}

private func quaternionVectorsApproximatelyEqual(
    _ lhs: SIMD4<Float>?,
    _ rhs: SIMD4<Float>,
    tolerance: Float = 0.000_1
) -> Bool {
    guard let lhs else { return false }
    return simd_length(lhs - rhs) <= tolerance
}
