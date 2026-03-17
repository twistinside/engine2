//
//  RotatableTests.swift
//  Engine2Tests
//
//  Created by Codex on 3/15/26.
//

import Testing
import simd
@testable import Engine2

struct RotatableTests {
    @Test func rotationReadsFromWorldStore() async throws {
        let world = World()
        let entity = TestRotatableEntity(id: EntityID(index: 0, generation: 0), in: world)
        let expectedRotation = simd_quatf(angle: .pi / 4, axis: SIMD3<Float>(0, 1, 0))

        world.rotationComponents.insert(CRotation(rotation: expectedRotation), for: entity.id)

        #expect(entity.rotation.vector == expectedRotation.vector)
    }
}

private final class TestRotatableEntity: Entity, Orientable {}
