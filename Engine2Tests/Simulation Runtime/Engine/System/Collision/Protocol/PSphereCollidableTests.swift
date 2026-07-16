//
//  PSphereCollidableTests.swift
//  Engine2Tests
//
//  Created by Codex on 7/15/26.
//

import Testing
@testable import Engine2

struct PSphereCollidableTests {
    @Test func boundingRadiusReadsFromWorldStore() {
        let world = World()
        let entity = TestSphereEntity(
            unregisteredID: world.reserveEntityID(),
            in: world
        )

        world.add(
            entity,
            from: Entity.InitialState(position: SIMD3<Float>(1, 2, 3))
        )

        #expect(entity.boundingSphereRadius == 2.5)
        #expect(world.boundingSphereComponents[entity.id]?.radius == 2.5)
    }
}
private final class TestSphereEntity: Entity, PSphereCollidable {
    let initialBoundingSphereRadius: Float = 2.5
}
