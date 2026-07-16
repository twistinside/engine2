//
//  CollisionWorldBuilderTests.swift
//  Engine2Tests
//
//  Created by Codex on 7/15/26.
//

import Testing
@testable import Engine2

struct CollisionWorldBuilderTests {
    @Test func collisionWorldSeedsTwoVisibleApproachingPairs() {
        let world = CollisionWorldBuilder().buildWorld()

        #expect(world.positionComponents.entities.count == 4)
        #expect(world.motionComponents.entities.count == 4)
        #expect(world.boundingSphereComponents.entities.count == 4)
        #expect(
            world.camera == Camera(
                position: SIMD3<Float>(0, 0, 8),
                orthographicHeight: 8
            )
        )

        let entities = world.positionComponents.entities
        #expect(
            entities.compactMap { world.motionComponents[$0]?.velocity } == [
                SIMD3<Float>(2, 0, 0),
                SIMD3<Float>(-2, 0, 0),
                SIMD3<Float>(3, 0, 0),
                SIMD3<Float>(-3, 0, 0)
            ]
        )
    }

    @Test func collisionWorldPairsActuallyCollideAfterOneSecond() {
        let world = CollisionWorldBuilder().buildWorld()
        let entities = world.positionComponents.entities
        let engine = Engine(
            world: world,
            fixedTimeStep: .seconds(1),
            alwaysSystems: []
        )

        engine.step()

        #expect(
            entities.compactMap { world.motionComponents[$0]?.velocity } == [
                SIMD3<Float>(-2, 0, 0),
                SIMD3<Float>(2, 0, 0),
                SIMD3<Float>(-3, 0, 0),
                SIMD3<Float>(3, 0, 0)
            ]
        )
        #expect(
            entities.compactMap { world.positionComponents[$0]?.position } == [
                SIMD3<Float>(-1, -1.5, 0),
                SIMD3<Float>(1, -1.5, 0),
                SIMD3<Float>(-1, 1.5, 0),
                SIMD3<Float>(1, 1.5, 0)
            ]
        )
    }

    @Test func collisionDemoContentSelectsCollisionWorldBuilder() {
        #expect(
            BasicGameContent.collisionDemo.worldBuilder is CollisionWorldBuilder
        )
    }
}
