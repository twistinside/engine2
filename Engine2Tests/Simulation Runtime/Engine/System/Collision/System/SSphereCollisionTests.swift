//
//  SSphereCollisionTests.swift
//  Engine2Tests
//
//  Created by Codex on 7/15/26.
//

import Testing
@testable import Engine2

struct SSphereCollisionTests {
    @Test func overlappingHeadOnSpheresSeparateAndExchangeNormalVelocity() {
        var world = World()
        let first = insertSphere(
            at: SIMD3<Float>(-0.75, 0, 0),
            velocity: SIMD3<Float>(1, 2, 0),
            index: 0,
            into: &world
        )
        let second = insertSphere(
            at: SIMD3<Float>(0.75, 0, 0),
            velocity: SIMD3<Float>(-1, -3, 0),
            index: 1,
            into: &world
        )

        SSphereCollision().update(world: &world, deltaTime: 1 / 60)

        #expect(
            world.positionComponents[first]?.position ==
                SIMD3<Float>(-1, 0, 0)
        )
        #expect(
            world.positionComponents[second]?.position ==
                SIMD3<Float>(1, 0, 0)
        )
        #expect(
            world.motionComponents[first]?.velocity ==
                SIMD3<Float>(-1, 2, 0)
        )
        #expect(
            world.motionComponents[second]?.velocity ==
                SIMD3<Float>(1, -3, 0)
        )
    }

    @Test func separatingOverlapCorrectsPositionWithoutAnotherImpulse() {
        var world = World()
        let first = insertSphere(
            at: SIMD3<Float>(-0.75, 0, 0),
            velocity: SIMD3<Float>(-1, 0, 0),
            index: 0,
            into: &world
        )
        let second = insertSphere(
            at: SIMD3<Float>(0.75, 0, 0),
            velocity: SIMD3<Float>(1, 0, 0),
            index: 1,
            into: &world
        )

        SSphereCollision().update(world: &world, deltaTime: 1 / 60)

        #expect(world.positionComponents[first]?.position.x == -1)
        #expect(world.positionComponents[second]?.position.x == 1)
        #expect(
            world.motionComponents[first]?.velocity == SIMD3<Float>(-1, 0, 0)
        )
        #expect(
            world.motionComponents[second]?.velocity == SIMD3<Float>(1, 0, 0)
        )
    }

    @Test func separatedSpheresRemainUnchanged() {
        var world = World()
        let first = insertSphere(
            at: SIMD3<Float>(-2, 0, 0),
            velocity: SIMD3<Float>(1, 0, 0),
            index: 0,
            into: &world
        )
        let second = insertSphere(
            at: SIMD3<Float>(2, 0, 0),
            velocity: SIMD3<Float>(-1, 0, 0),
            index: 1,
            into: &world
        )

        SSphereCollision().update(world: &world, deltaTime: 1 / 60)

        #expect(world.positionComponents[first]?.position.x == -2)
        #expect(world.positionComponents[second]?.position.x == 2)
        #expect(world.motionComponents[first]?.velocity.x == 1)
        #expect(world.motionComponents[second]?.velocity.x == -1)
    }

    @Test func coincidentCentersUseVelocityForAStableCollisionNormal() {
        var world = World()
        let first = insertSphere(
            at: .zero,
            velocity: SIMD3<Float>(1, 0, 0),
            index: 0,
            into: &world
        )
        let second = insertSphere(
            at: .zero,
            velocity: SIMD3<Float>(-1, 0, 0),
            index: 1,
            into: &world
        )

        SSphereCollision().update(world: &world, deltaTime: 1 / 60)

        #expect(world.positionComponents[first]?.position.x == -1)
        #expect(world.positionComponents[second]?.position.x == 1)
        #expect(world.motionComponents[first]?.velocity.x == -1)
        #expect(world.motionComponents[second]?.velocity.x == 1)
    }

    private func insertSphere(
        at position: SIMD3<Float>,
        velocity: SIMD3<Float>,
        radius: Float = 1,
        index: Int,
        into world: inout World
    ) -> EntityID {
        let entity = EntityID(index: index, generation: 0)
        world.positionComponents.insert(
            CPosition(position: position),
            for: entity
        )
        world.motionComponents.insert(
            CMotion(velocity: velocity),
            for: entity
        )
        world.boundingSphereComponents.insert(
            CBoundingSphere(radius: radius),
            for: entity
        )
        return entity
    }
}
