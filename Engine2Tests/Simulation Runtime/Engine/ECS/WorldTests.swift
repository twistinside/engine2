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
        #expect(world.motionComponents[entity.id] == nil)
        #expect(world.boundingSphereComponents[entity.id] == nil)
        #expect(world.renderableComponents[entity.id] == nil)
        #expect(world.rotationComponents[entity.id] == nil)
        #expect(world.selectableComponents[entity.id] == nil)
    }

    @Test func addSeedsAccelerationIntentForMovableEntity() async throws {
        let world = World()
        let entity = TestMovableSpawnEntity(unregisteredID: world.reserveEntityID(), in: world)
        let expectedIntent = CMotion.AccelerationIntent.accelerating(SIMD3<Float>(1, 2, 3))

        world.add(
            entity,
            from: Entity.InitialState(accelerationIntent: expectedIntent)
        )

        #expect(world.motionComponents[entity.id]?.accelerationIntent == expectedIntent)
        #expect(entity.accelerationIntent == expectedIntent)
    }

    @Test func addSeedsSelectionStateForSelectableEntity() async throws {
        let world = World()
        let entity = TestSelectableSpawnEntity(unregisteredID: world.reserveEntityID(), in: world)
        let expectedState = CSelectable.SelectionState.selected

        world.add(
            entity,
            from: Entity.InitialState(selectionState: expectedState)
        )

        #expect(world.selectableComponents[entity.id]?.selectionState == expectedState)
        #expect(entity.selectionState == expectedState)
    }

    @Test func addSeedsMeshIdentityForRenderableEntity() async throws {
        let world = World()
        let entity = TestRenderableSpawnEntity(
            unregisteredID: world.reserveEntityID(),
            in: world
        )

        world.add(entity)

        #expect(world.renderableComponents[entity.id]?.meshID == entity.initialMeshID)
        #expect(entity.meshID == entity.initialMeshID)
    }

    @Test func addSeedsBoundingSphereForCollidableEntity() {
        let world = World()
        let entity = TestSphereCollidableSpawnEntity(
            unregisteredID: world.reserveEntityID(),
            in: world
        )

        world.add(
            entity,
            from: Entity.InitialState(position: SIMD3<Float>(1, 2, 3))
        )

        #expect(world.boundingSphereComponents[entity.id]?.radius == 2)
        #expect(entity.boundingSphereRadius == 2)
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

private final class TestSpawnEntity: Entity, PPositionable, PScalable {}
private final class TestMovableSpawnEntity: Entity, PMovable {}
private final class TestSelectableSpawnEntity: Entity, PSelectable {}
private final class TestRenderableSpawnEntity: Entity, PRenderable {
    let initialMeshID = MeshID.ball
}
private final class TestSphereCollidableSpawnEntity: Entity, PSphereCollidable {
    let initialBoundingSphereRadius: Float = 2
}
