//
//  EngineTests.swift
//  Engine2Tests
//
//  Created by Codex on 3/10/26.
//

import Testing
@testable import Engine2

struct EngineTests {
    @MainActor
    @Test func updateAccumulatesTimeUntilFixedStepBoundary() async throws {
        let world = World()
        let entity = EntityID(index: 0, generation: 0)

        world.positionComponents.insert(CPosition(position: SIMD3<Float>(1, 2, 3)), for: entity)
        world.velocityComponents.insert(CVelocity(velocity: SIMD3<Float>(4, 5, 6)), for: entity)
        world.motionAccumulatorComponents.insert(
            CMotionAccumulator(
                acceleration: SIMD3<Float>(2, 0, -2),
                impulse: SIMD3<Float>(1, -1, 0.5)
            ),
            for: entity
        )

        let engine = Engine(world: world, fixedTimeStep: 0.5, systems: [SMovement()])

        engine.update(deltaTime: 0.49)

        #expect(world.velocityComponents[entity]?.velocity == SIMD3<Float>(4, 5, 6))
        #expect(world.positionComponents[entity]?.position == SIMD3<Float>(1, 2, 3))
        #expect(engine.accumulatedTime == 0.49)

        engine.update(deltaTime: 0.01)

        #expect(world.velocityComponents[entity]?.velocity == SIMD3<Float>(6, 4, 5.5))
        #expect(world.positionComponents[entity]?.position == SIMD3<Float>(4, 4, 5.75))
        #expect(engine.accumulatedTime == 0)
    }
}
