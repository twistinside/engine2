//
//  SAccelerationIntentTests.swift
//  Engine2Tests
//
//  Created by Codex on 5/31/26.
//

import Testing
@testable import Engine2

struct SAccelerationIntentTests {
    @Test func acceleratingIntentEmitsAccelerationEveryStep() async throws {
        var world = World()
        let entity = EntityID(index: 0, generation: 0)

        world.positionComponents.insert(CPosition(position: .zero), for: entity)
        world.motionComponents.insert(
            CMotion(
                velocity: .zero,
                accelerationIntent: .accelerating(SIMD3<Float>(2, 0, 0))
            ),
            for: entity
        )

        var intentSystem = SAccelerationIntent()
        let movementSystem = SMovement()

        intentSystem.update(world: &world, deltaTime: 0.5)
        movementSystem.update(world: &world, deltaTime: 0.5)

        #expect(world.motionComponents[entity]?.velocity == SIMD3<Float>(1, 0, 0))
        #expect(world.positionComponents[entity]?.position == SIMD3<Float>(0.5, 0, 0))
        #expect(world.motionComponents[entity]?.acceleration == .zero)
        #expect(world.motionComponents[entity]?.accelerationIntent == .accelerating(SIMD3<Float>(2, 0, 0)))

        intentSystem.update(world: &world, deltaTime: 0.5)
        movementSystem.update(world: &world, deltaTime: 0.5)

        #expect(world.motionComponents[entity]?.velocity == SIMD3<Float>(2, 0, 0))
        #expect(world.positionComponents[entity]?.position == SIMD3<Float>(1.5, 0, 0))
        #expect(world.motionComponents[entity]?.acceleration == .zero)
    }

    @Test func idleIntentDoesNotEmitAcceleration() async throws {
        var world = World()
        let entity = EntityID(index: 0, generation: 0)

        world.motionComponents.insert(
            CMotion(accelerationIntent: .idle),
            for: entity
        )

        var system = SAccelerationIntent()
        system.update(world: &world, deltaTime: 1)

        #expect(world.motionComponents[entity]?.acceleration == .zero)
        #expect(world.motionComponents[entity]?.accelerationIntent == .idle)
    }
}
