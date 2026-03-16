//
//  SMovementTests.swift
//  Engine2Tests
//
//  Created by Karl Groff on 3/8/26.
//

import Testing
@testable import Engine2

struct SMovementTests {
    @Test func integratesVelocityAndClearsAccumulator() async throws {
        var world = World()
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

        let system = SMovement()
        system.update(world: &world, deltaTime: 0.5)

        #expect(world.velocityComponents[entity]?.velocity == SIMD3<Float>(6, 4, 5.5))
        #expect(world.positionComponents[entity]?.position == SIMD3<Float>(4, 4, 5.75))
        #expect(world.motionAccumulatorComponents[entity]?.acceleration == .zero)
        #expect(world.motionAccumulatorComponents[entity]?.impulse == .zero)
    }
}
