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
        let expectedIntent = MotionComponent.AccelerationIntent.accelerating(
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
        let expectedState = SelectableComponent.SelectionState.selected
        let initialState = Entity.InitialState(
            selectionState: expectedState,
            selectionRadius: 2
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
        world.add(
            entity,
            from: Entity.InitialState(meshID: expectedMeshID, materialID: expectedMaterialID)
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
        let primary = TestSpawnEntity(in: world, from: Entity.InitialState(position: .zero))
        let entity = TestCompleteSpawnEntity(
            unregisteredID: world.reserveEntityID(),
            in: world
        )
        let state = completeInitialState(primary: primary.id)

        world.add(entity, from: state)

        #expect(world.angularMotionAccumulatorComponents[entity.id] != nil)
        #expect(world.angularVelocityComponents[entity.id] != nil)
        #expect(world.cargoComponents[entity.id]?.capacity == state.cargoCapacity)
        #expect(world.cargoComponents[entity.id]?.ore == state.cargoOre)
        #expect(world.collisionBodyComponents[entity.id]?.radius == state.collisionRadius)
        #expect(world.collisionBodyComponents[entity.id]?.response == state.collisionResponse)
        #expect(world.collisionBodyComponents[entity.id]?.ownerPolicy == state.collisionOwnerPolicy)
        #expect(world.collisionBodyComponents[entity.id]?.contactScope == state.collisionContactScope)
        #expect(world.depotServiceComponents[entity.id]?.unloadingRate == state.depotUnloadingRate)
        #expect(world.depotServiceComponents[entity.id]?.refuelingRate == state.depotRefuelingRate)
        #expect(world.depotServiceComponents[entity.id]?.deliveredOre == 0)
        #expect(world.displayNameComponents[entity.id]?.value == state.displayName)
        #expect(world.fuelComponents[entity.id]?.capacity == state.fuelCapacity)
        #expect(world.fuelComponents[entity.id]?.remaining == state.fuelRemaining)
        #expect(world.gravityReceiverComponents[entity.id] != nil)
        #expect(world.gravitySourceComponents[entity.id]?.gravitationalParameter == state.gravitationalParameter)
        #expect(world.interactionComponents[entity.id]?.interactionRange == state.interactionRange)
        #expect(world.massComponents[entity.id]?.dryMass == state.dryMass)
        #expect(world.mineableComponents[entity.id]?.miningRate == state.miningRate)
        #expect(world.contactConsumptionComponents[entity.id] != nil)
        #expect(world.contactDamageComponents[entity.id]?.amount.rawValue == state.contactDamage)
        #expect(world.healthComponents[entity.id]?.health.rawValue == state.health)
        #expect(world.ownershipComponents[entity.id]?.ownerEntityID == state.ownerEntityID)
        #expect(world.lifetimeComponents[entity.id]?.remainingLifetime == state.lifetime)
        #expect(world.missileLauncherComponents[entity.id]?.speed == state.missileSpeed)
        #expect(world.missileLauncherComponents[entity.id]?.lifetime == state.missileLifetime)
        #expect(world.missileLauncherComponents[entity.id]?.radius == state.missileRadius)
        #expect(world.motionComponents[entity.id] != nil)
        #expect(world.orbitCircularizationAutopilotComponents[entity.id] == .idle)
        #expect(world.orbitPrimaryComponents[entity.id]?.primaryEntityID == state.orbitPrimaryID)
        #expect(world.orbitalRailComponents[entity.id] == nil)
        #expect(world.oreDepositComponents[entity.id]?.remainingOre == state.remainingOre)
        #expect(world.playerControlComponents[entity.id]?.translation == .zero)
        #expect(world.playerControlComponents[entity.id]?.interactionState == .inactive)
        #expect(world.playerControlComponents[entity.id]?.isFireRequested == false)
        #expect(world.positionComponents[entity.id]?.position == state.position)
        #expect(world.previousPositionComponents[entity.id]?.position == state.position)
        #expect(world.propulsionComponents[entity.id]?.maximumThrust == state.maximumThrust)
        #expect(world.propulsionComponents[entity.id]?.exhaustVelocity == state.exhaustVelocity)
        #expect(world.renderableComponents[entity.id]?.meshID == state.meshID)
        #expect(world.renderableComponents[entity.id]?.materialID == state.materialID)
        #expect(world.rotationComponents[entity.id]?.rotation.vector == state.rotation?.vector)
        #expect(world.scaleComponents[entity.id]?.scale == state.scale)
        #expect(world.selectableComponents[entity.id]?.selectionState == .selected)
        #expect(world.selectionBoundsComponents[entity.id]?.radius == state.selectionRadius)
        #expect(world.selectedEntityID == entity.id)
    }

    @Test func destroyRemovesEveryComponentAndLiveResourceReference() {
        let world = World()
        let primary = TestSpawnEntity(in: world, from: Entity.InitialState(position: .zero))
        let entity = TestCompleteSpawnEntity(
            unregisteredID: world.reserveEntityID(),
            in: world
        )
        world.add(entity, from: completeInitialState(primary: primary.id))
        world.cameraFollowEntityID = entity.id
        world.orbitCircularizationCommand = OrbitCircularizationCommand(entityID: entity.id)

        #expect(world.destroy(entity.id))

        #expect(world.entity(for: entity.id) == nil)
        #expect(world.registeredEntities.map(\.id) == [primary.id])
        #expect(world.selectedEntityID == nil)
        #expect(world.cameraFollowEntityID == nil)
        #expect(world.orbitCircularizationCommand == nil)
        #expect(world.angularMotionAccumulatorComponents[entity.id] == nil)
        #expect(world.angularVelocityComponents[entity.id] == nil)
        #expect(world.cargoComponents[entity.id] == nil)
        #expect(world.collisionBodyComponents[entity.id] == nil)
        #expect(world.depotServiceComponents[entity.id] == nil)
        #expect(world.displayNameComponents[entity.id] == nil)
        #expect(world.fuelComponents[entity.id] == nil)
        #expect(world.gravityReceiverComponents[entity.id] == nil)
        #expect(world.gravitySourceComponents[entity.id] == nil)
        #expect(world.interactionComponents[entity.id] == nil)
        #expect(world.massComponents[entity.id] == nil)
        #expect(world.mineableComponents[entity.id] == nil)
        #expect(world.contactConsumptionComponents[entity.id] == nil)
        #expect(world.contactDamageComponents[entity.id] == nil)
        #expect(world.healthComponents[entity.id] == nil)
        #expect(world.ownershipComponents[entity.id] == nil)
        #expect(world.lifetimeComponents[entity.id] == nil)
        #expect(world.missileLauncherComponents[entity.id] == nil)
        #expect(world.motionComponents[entity.id] == nil)
        #expect(world.orbitCircularizationAutopilotComponents[entity.id] == nil)
        #expect(world.orbitPrimaryComponents[entity.id] == nil)
        #expect(world.orbitalRailComponents[entity.id] == nil)
        #expect(world.oreDepositComponents[entity.id] == nil)
        #expect(world.playerControlComponents[entity.id] == nil)
        #expect(world.positionComponents[entity.id] == nil)
        #expect(world.previousPositionComponents[entity.id] == nil)
        #expect(world.propulsionComponents[entity.id] == nil)
        #expect(world.renderableComponents[entity.id] == nil)
        #expect(world.rotationComponents[entity.id] == nil)
        #expect(world.scaleComponents[entity.id] == nil)
        #expect(world.selectableComponents[entity.id] == nil)
        #expect(world.selectionBoundsComponents[entity.id] == nil)
        #expect(world.select(entity.id) == false)
        #expect(world.destroy(entity.id) == false)
    }

    @Test func destructionRemovesRailStateWithoutRemovingItsPrimary() {
        let world = World()
        let primary = TestSpawnEntity(in: world, from: Entity.InitialState(position: .zero))
        let asteroid = Asteroid(
            in: world,
            name: "Orbiting target",
            primaryEntityID: primary.id,
            orbitalRadius: 60,
            angularSpeed: 0.1,
            phase: 0.2,
            physicalRadius: 1,
            ore: 10,
            interactionRange: 2,
            miningRate: 1,
            materialID: .warmDielectric
        )
        #expect(world.orbitalRailComponents[asteroid.id] != nil)

        #expect(world.destroy(asteroid.id))

        #expect(world.orbitalRailComponents[asteroid.id] == nil)
        #expect(world.positionComponents[asteroid.id] == nil)
        #expect(world.previousPositionComponents[asteroid.id] == nil)
        #expect(world.collisionBodyComponents[asteroid.id] == nil)
        #expect(world.registeredEntities.map(\.id) == [primary.id])
    }

    @Test func destroyRejectsStaleIdentityAndPreservesOtherLiveEntities() {
        let world = World()
        let removed = TestSelectableSpawnEntity(
            unregisteredID: world.reserveEntityID(),
            in: world
        )
        let survivor = TestSelectableSpawnEntity(
            unregisteredID: world.reserveEntityID(),
            in: world
        )
        let state = Entity.InitialState(selectionRadius: 1)
        world.add(removed, from: state)
        world.add(survivor, from: state)
        world.select(survivor.id)
        world.cameraFollowEntityID = survivor.id
        world.orbitCircularizationCommand = OrbitCircularizationCommand(entityID: survivor.id)

        #expect(world.destroy(EntityID(index: survivor.id.index, generation: 1)) == false)
        #expect(world.destroy(removed.id))

        #expect(world.registeredEntities.map(\.id) == [survivor.id])
        #expect(world.entity(for: survivor.id) === survivor)
        #expect(world.positionComponents.entities == [survivor.id])
        #expect(world.selectedEntityID == survivor.id)
        #expect(world.selectableComponents[survivor.id]?.selectionState == .selected)
        #expect(world.cameraFollowEntityID == survivor.id)
        #expect(world.orbitCircularizationCommand?.entityID == survivor.id)
    }

    @Test func destructionRemovesFuturePresentationsAndPreservesPublishedSnapshot() {
        let world = World()
        let entity = TestRenderableSpawnEntity(
            unregisteredID: world.reserveEntityID(),
            in: world
        )
        world.add(
            entity,
            from: Entity.InitialState(
                position: SIMD3<Double>(1, 2, 3),
                meshID: .ball,
                materialID: .goldMetal
            )
        )
        let cursor = SimulationCursor(sessionID: SimulationSessionID(), tick: SimulationTick(rawValue: 0))
        let published = world.presentationSnapshot(at: cursor)

        world.destroy(entity.id)
        let later = world.presentationSnapshot(at: cursor)

        #expect(published.entityPresentations.map(\.id) == [entity.id])
        #expect(published.entityPresentations.first?.position == SIMD3<Float>(1, 2, 3))
        #expect(later.entityPresentations.isEmpty)
    }

    @Test func destructionDoesNotReuseIdentityDuringLaterSpawning() {
        let world = World()
        let first = Entity(in: world, from: .empty)
        world.destroy(first.id)

        let second = Entity(in: world, from: .empty)

        #expect(second.id.index > first.id.index)
        #expect(second.id.generation == 0)
        #expect(world.entity(for: first.id) == nil)
        #expect(world.entity(for: second.id) === second)
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
            selectionRadius: 1
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
                selectionRadius: 1
            )
        )

        world.add(
            entity,
            from: Entity.InitialState(
                selectionRadius: 1
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
            selectionRadius: 1
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
    private func completeInitialState(primary: EntityID) -> Entity.InitialState {
        Entity.InitialState(
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
            cargoCapacity: 20,
            cargoOre: 3,
            collisionRadius: 2,
            collisionResponse: .solid(restitution: 0.35),
            collisionOwnerPolicy: .exclude,
            collisionContactScope: .solidBodies,
            contactDamage: 2,
            health: 3,
            depotUnloadingRate: 4,
            depotRefuelingRate: 5,
            displayName: "Complete",
            fuelCapacity: 30,
            fuelRemaining: 7,
            gravitationalParameter: 40,
            interactionRange: 8,
            dryMass: 50,
            miningRate: 9,
            ownerEntityID: primary,
            lifetime: 12,
            missileSpeed: 45,
            missileLifetime: 10,
            missileRadius: 0.5,
            orbitPrimaryID: primary,
            remainingOre: 70,
            maximumThrust: 80,
            exhaustVelocity: 90,
            meshID: .ball,
            materialID: .goldMetal,
            selectionRadius: 10
        )
    }
}

private extension WorldTests {
    private final class TestSpawnEntity: Entity, Positionable, Scalable {}
    private final class TestMovableSpawnEntity: Entity, Movable {}
    private final class TestSelectableSpawnEntity: Entity, Selectable {}
    private final class TestRenderableSpawnEntity: Entity, Renderable {}
    private final class TestCompleteSpawnEntity: Entity, CargoCarrying, Collidable,
        DepotServicing, DisplayNamed, Fueled, GravityAffected, GravitySource,
        LiveMass, Mineable, MissileLaunching, Ownable, Expirable, ContactDamaging, ContactConsumable, Damageable, OrbitCircularizable,
        PlayerControlled, Propelled, Renderable, Rotatable, Scalable, Selectable {}
}
