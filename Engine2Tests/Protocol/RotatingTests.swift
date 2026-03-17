//
//  RotatingTests.swift
//  Engine2Tests
//
//  Created by Codex on 3/15/26.
//

import Testing
@testable import Engine2

struct RotatingTests {
    @Test func angularMotionReadsFromWorldStores() async throws {
        let world = World()
        let entity = TestRotatingEntity(unregisteredID: EntityID(index: 0, generation: 0), in: world)
        let expectedAngularAcceleration = SIMD3<Float>(0.1, 0.2, 0.3)
        let expectedAngularImpulse = SIMD3<Float>(0.05, 0.15, 0.25)
        let expectedAngularVelocity = SIMD3<Float>(0.25, 0.5, 1)

        world.angularMotionAccumulatorComponents.insert(
            CAngularMotionAccumulator(
                angularAcceleration: expectedAngularAcceleration,
                angularImpulse: expectedAngularImpulse
            ),
            for: entity.id
        )
        world.angularVelocityComponents.insert(
            CAngularVelocity(angularVelocity: expectedAngularVelocity),
            for: entity.id
        )

        #expect(entity.angularAcceleration == expectedAngularAcceleration)
        #expect(entity.angularImpulse == expectedAngularImpulse)
        #expect(entity.angularVelocity == expectedAngularVelocity)
    }
}

private final class TestRotatingEntity: Entity, Rotatable {}
