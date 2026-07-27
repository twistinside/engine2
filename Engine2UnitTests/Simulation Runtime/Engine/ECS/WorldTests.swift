import Testing
@testable import Engine2

struct WorldTests {
    @Test func addSeedsOnlyAdvertisedCapabilityComponents() async throws {
        let world = World()
        let entity = TestSpawnEntity(unregisteredID: world.reserveEntityID(), in: world)
        let expectedPosition = SIMD3<Float>(1, 2, 3)
        let expectedScale = SIMD3<Float>(2, 2, 2)
        let initialState = Entity.InitialState(
            position: expectedPosition,
            scale: expectedScale
        )

        world.add(
            entity,
            from: initialState
        )

        #expect(world.positionComponents[entity.id]?.position == expectedPosition)
        #expect(world.scaleComponents[entity.id]?.scale == expectedScale)
        #expect(world.motionComponents[entity.id] == nil)
        #expect(world.renderableComponents[entity.id] == nil)
        #expect(world.rotationComponents[entity.id] == nil)
        #expect(world.selectableComponents[entity.id] == nil)
    }

    @Test func addSeedsAccelerationIntentForMovableEntity() async throws {
        let world = World()
        let entity = TestMovableSpawnEntity(unregisteredID: world.reserveEntityID(), in: world)
        let expectedIntent = CMotion.AccelerationIntent.accelerating(SIMD3<Float>(1, 2, 3))
        let initialState = Entity.InitialState(accelerationIntent: expectedIntent)

        world.add(
            entity,
            from: initialState
        )

        #expect(world.motionComponents[entity.id]?.accelerationIntent == expectedIntent)
        #expect(entity.accelerationIntent == expectedIntent)
    }

    @Test func addSeedsSelectionStateForSelectableEntity() async throws {
        let world = World()
        let entity = TestSelectableSpawnEntity(unregisteredID: world.reserveEntityID(), in: world)
        let expectedState = CSelectable.SelectionState.selected
        let initialState = Entity.InitialState(selectionState: expectedState)

        world.add(
            entity,
            from: initialState
        )

        #expect(world.selectableComponents[entity.id]?.selectionState == expectedState)
        #expect(entity.selectionState == expectedState)
    }

    @Test func addSeedsMeshAndMaterialIdentityForRenderableEntity() async throws {
        let world = World()
        let entity = TestRenderableSpawnEntity(
            unregisteredID: world.reserveEntityID(),
            in: world
        )
        let expectedMeshID = MeshID.ball
        let expectedMaterialID = MaterialID.goldMetal
        let renderableInitialState = RenderableInitialState(
            meshID: expectedMeshID,
            materialID: expectedMaterialID
        )

        world.add(
            entity,
            renderable: renderableInitialState
        )

        #expect(world.renderableComponents[entity.id]?.meshID == expectedMeshID)
        #expect(
            world.renderableComponents[entity.id]?.materialID ==
                expectedMaterialID
        )
        #expect(entity.meshID == expectedMeshID)
        #expect(entity.materialID == expectedMaterialID)
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

private extension WorldTests {
    private final class TestSpawnEntity: Entity, PPositionable, PScalable {}
    private final class TestMovableSpawnEntity: Entity, PMovable {}
    private final class TestSelectableSpawnEntity: Entity, PSelectable {}
    private final class TestRenderableSpawnEntity: Entity, PRenderable {}
}
