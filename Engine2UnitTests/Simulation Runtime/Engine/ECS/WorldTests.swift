import Testing
import simd
@testable import Engine2

struct WorldTests {
    @Test func addSeedsOnlyAdvertisedCapabilityComponents() async throws {
        let world = World()
        let entity = TestSpawnEntity(unregisteredID: world.reserveEntityID(), in: world)
        let expectedPosition = SIMD3<Double>(1, 2, 3)
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
        let expectedIntent = CMotion.AccelerationIntent.accelerating(
            SIMD3<Double>(1, 2, 3)
        )
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
        let initialState = Entity.InitialState(
            selectionState: expectedState,
            selectionBounds: CSelectionBounds(radius: 2)
        )

        world.add(
            entity,
            from: initialState
        )

        #expect(world.selectableComponents[entity.id]?.selectionState == expectedState)
        #expect(entity.selectionState == expectedState)
        #expect(world.selectedEntityID == entity.id)
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
            from: Entity.InitialState(renderable: renderableInitialState)
        )

        #expect(world.renderableComponents[entity.id]?.meshID == expectedMeshID)
        #expect(
            world.renderableComponents[entity.id]?.materialID ==
                expectedMaterialID
        )
        #expect(entity.meshID == expectedMeshID)
        #expect(entity.materialID == expectedMaterialID)
        #expect(entity.position == .zero)
    }

    @Test func addRegistersEveryAdvertisedComponentSeed() {
        let world = World()
        let entity = TestCompleteSpawnEntity(
            unregisteredID: world.reserveEntityID(),
            in: world
        )
        let primary = EntityID(index: 100, generation: 3)
        let state = Entity.InitialState(
            position: SIMD3<Double>(1, 2, 3),
            velocity: SIMD3<Double>(4, 5, 6),
            accelerationIntent: .accelerating(SIMD3<Double>(7, 8, 9)),
            impulse: SIMD3<Double>(10, 11, 12),
            rotation: simd_quatf(angle: 0.25, axis: SIMD3<Float>(0, 0, 1)),
            angularVelocity: SIMD3<Float>(1, 2, 3),
            angularAcceleration: SIMD3<Float>(4, 5, 6),
            angularImpulse: SIMD3<Float>(7, 8, 9),
            scale: SIMD3<Float>(repeating: 2),
            selectionState: .selected,
            cargo: CCargo(capacity: 20, ore: 3),
            collisionBody: CCollisionBody(radius: 2, restitution: 0.35),
            depotService: CDepotService(
                unloadingRate: 4,
                refuelingRate: 5,
                deliveredOre: 6
            ),
            displayName: CDisplayName(value: "Complete"),
            fuel: CFuel(capacity: 30, remaining: 7),
            gravityReceiver: CGravityReceiver(),
            gravitySource: CGravitySource(gravitationalParameter: 40),
            interaction: CInteraction(interactionRange: 8),
            mass: CMass(dryMass: 50),
            mineable: CMineable(miningRate: 9),
            orbitPrimary: COrbitPrimary(primaryEntityID: primary),
            orbitalRail: COrbitalRail(
                primaryEntityID: primary,
                radius: 60,
                angularSpeed: 0.1,
                phase: 0.2
            ),
            oreDeposit: COreDeposit(remainingOre: 70),
            playerControl: CPlayerControl(
                translation: SIMD2<Double>(0.5, -0.5),
                interactionState: .active
            ),
            previousPosition: CPreviousPosition(position: SIMD3<Double>(-1, -2, -3)),
            propulsion: CPropulsion(maximumThrust: 80, exhaustVelocity: 90),
            renderable: RenderableInitialState(meshID: .ball, materialID: .goldMetal),
            selectionBounds: CSelectionBounds(radius: 10)
        )

        world.add(entity, from: state)

        #expect(world.angularMotionAccumulatorComponents[entity.id] != nil)
        #expect(world.angularVelocityComponents[entity.id] != nil)
        #expect(world.cargoComponents[entity.id] == state.cargo)
        #expect(world.collisionBodyComponents[entity.id] == state.collisionBody)
        #expect(world.depotServiceComponents[entity.id] == state.depotService)
        #expect(world.displayNameComponents[entity.id] == state.displayName)
        #expect(world.fuelComponents[entity.id] == state.fuel)
        #expect(world.gravityReceiverComponents[entity.id] == state.gravityReceiver)
        #expect(world.gravitySourceComponents[entity.id] == state.gravitySource)
        #expect(world.interactionComponents[entity.id] == state.interaction)
        #expect(world.massComponents[entity.id] == state.mass)
        #expect(world.mineableComponents[entity.id] == state.mineable)
        #expect(world.motionComponents[entity.id] != nil)
        #expect(world.orbitCircularizationAutopilotComponents[entity.id] == .idle)
        #expect(world.orbitPrimaryComponents[entity.id] == state.orbitPrimary)
        #expect(world.orbitalRailComponents[entity.id] == state.orbitalRail)
        #expect(world.oreDepositComponents[entity.id] == state.oreDeposit)
        #expect(world.playerControlComponents[entity.id] == state.playerControl)
        #expect(world.positionComponents[entity.id]?.position == state.position)
        #expect(world.previousPositionComponents[entity.id] == state.previousPosition)
        #expect(world.propulsionComponents[entity.id] == state.propulsion)
        #expect(world.renderableComponents[entity.id]?.meshID == state.renderable?.meshID)
        #expect(world.renderableComponents[entity.id]?.materialID == state.renderable?.materialID)
        #expect(world.rotationComponents[entity.id]?.rotation.vector == state.rotation?.vector)
        #expect(world.scaleComponents[entity.id]?.scale == state.scale)
        #expect(world.selectableComponents[entity.id]?.selectionState == .selected)
        #expect(world.selectionBoundsComponents[entity.id] == state.selectionBounds)
        #expect(world.selectedEntityID == entity.id)
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

    @Test func repeatedRegistrationOfTheSameFacadeIsIdempotent() {
        let world = World()
        let entity = TestSelectableSpawnEntity(unregisteredID: world.reserveEntityID(), in: world)
        let state = Entity.InitialState(
            selectionBounds: CSelectionBounds(radius: 1)
        )

        world.add(entity, from: state)
        world.add(entity, from: state)

        #expect(world.registeredEntities.count == 1)
        #expect(world.entity(for: entity.id) === entity)
    }

    @Test func repeatedRegistrationCannotDesynchronizeSelectedState() {
        let world = World()
        let entity = TestSelectableSpawnEntity(unregisteredID: world.reserveEntityID(), in: world)
        world.add(
            entity,
            from: Entity.InitialState(
                selectionState: .selected,
                selectionBounds: CSelectionBounds(radius: 1)
            )
        )

        world.add(
            entity,
            from: Entity.InitialState(
                selectionBounds: CSelectionBounds(radius: 1)
            )
        )

        #expect(world.selectedEntityID == entity.id)
        #expect(world.selectableComponents[entity.id]?.selectionState == .selected)
    }

    @Test func selectSynchronizesTheResourceAndEverySelectableRow() {
        let world = World()
        let first = TestSelectableSpawnEntity(unregisteredID: world.reserveEntityID(), in: world)
        let second = TestSelectableSpawnEntity(unregisteredID: world.reserveEntityID(), in: world)
        let state = Entity.InitialState(
            selectionBounds: CSelectionBounds(radius: 1)
        )
        world.add(first, from: state)
        world.add(second, from: state)

        #expect(world.select(second.id))
        #expect(world.selectedEntityID == second.id)
        #expect(world.selectableComponents[first.id]?.selectionState == .unselected)
        #expect(world.selectableComponents[second.id]?.selectionState == .selected)

        #expect(world.select(nil))
        #expect(world.selectedEntityID == nil)
        #expect(world.selectableComponents[second.id]?.selectionState == .unselected)
    }
}

private extension WorldTests {
    private final class TestSpawnEntity: Entity, PPositionable, PScalable {}
    private final class TestMovableSpawnEntity: Entity, PMovable {}
    private final class TestSelectableSpawnEntity: Entity, PSelectable {}
    private final class TestRenderableSpawnEntity: Entity, PRenderable {}
    private final class TestCompleteSpawnEntity: Entity, PCargoCarrying, PCollidable,
        PDepotServicing, PDisplayNamed, PFueled, PGravityAffected, PGravitySource,
        PLiveMass, PMineable, POrbitCircularizable, POrbiting, PPlayerControlled,
        PPropelled, PRenderable, PRotatable, PScalable, PSelectable {}
}
