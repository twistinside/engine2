//
//  WorldTests.swift
//  Engine2Tests
//
//  Created by Codex on 3/17/26.
//

import Testing
@testable import Engine2

struct WorldTests {
    @Test func addSeedsOnlyAdvertisedCapabilityComponents() async throws {
        let world = World()
        let entity = TestSpawnEntity(unregisteredID: world.reserveEntityID(), in: world)
        let expectedPosition = SIMD3<Float>(1, 2, 3)
        let expectedScale = SIMD3<Float>(2, 2, 2)

        world.add(
            entity,
            from: Entity.InitialState(
                position: expectedPosition,
                scale: expectedScale
            )
        )

        #expect(world.positionComponents[entity.id]?.position == expectedPosition)
        #expect(world.scaleComponents[entity.id]?.scale == expectedScale)
        #expect(world.velocityComponents[entity.id] == nil)
        #expect(world.rotationComponents[entity.id] == nil)
    }

    @Test func reserveEntityIDReturnsUniqueHandles() async throws {
        let world = World()
        let first = world.reserveEntityID()
        let second = world.reserveEntityID()

        #expect(first != second)
        #expect(first.index == 0)
        #expect(second.index == 1)
        #expect(first.generation == 0)
        #expect(second.generation == 0)
    }
}

private final class TestSpawnEntity: Entity, Positionable, Scalable {}
