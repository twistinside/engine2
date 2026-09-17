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

        #expect(world.components[DestructibleComponent.self][entity.id]?.state == .active)
        #expect(world.components[PositionComponent.self][entity.id]?.position == expectedPosition)
        #expect(world.components[ScaleComponent.self][entity.id]?.scale == expectedScale)
        #expect(world.components[MotionComponent.self][entity.id] == nil)
        #expect(world.components[RenderableComponent.self][entity.id] == nil)
        #expect(world.components[RotationComponent.self][entity.id] == nil)
        #expect(world.components[SelectableComponent.self][entity.id] == nil)
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

        #expect(world.components[MotionComponent.self][entity.id]?.accelerationIntent == expectedIntent)
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

        #expect(world.components[SelectableComponent.self][entity.id]?.selectionState == expectedState)
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

        #expect(world.components[RenderableComponent.self][entity.id]?.meshID == expectedMeshID)
        #expect(
            world.components[RenderableComponent.self][entity.id]?.materialID ==
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

        #expect(world.components[DestructibleComponent.self][entity.id]?.state == .active)
        #expect(Set(world.components[DestructibleComponent.self].entities) == Set(world.registeredEntities.map(\.id)))
        #expect(world.components[AngularMotionAccumulatorComponent.self][entity.id] != nil)
        #expect(world.components[AngularVelocityComponent.self][entity.id] != nil)
        #expect(world.components[CargoComponent.self][entity.id]?.capacity == state.cargoCapacity)
        #expect(world.components[CargoComponent.self][entity.id]?.ore == state.cargoOre)
        #expect(world.components[CollisionBodyComponent.self][entity.id]?.radius == state.collisionRadius)
        #expect(world.components[CollisionBodyComponent.self][entity.id]?.response == state.collisionResponse)
        #expect(world.components[CollisionBodyComponent.self][entity.id]?.ownerPolicy == state.collisionOwnerPolicy)
        #expect(world.components[CollisionBodyComponent.self][entity.id]?.contactScope == state.collisionContactScope)
        #expect(world.components[DepotServiceComponent.self][entity.id]?.unloadingRate == state.depotUnloadingRate)
        #expect(world.components[DepotServiceComponent.self][entity.id]?.refuelingRate == state.depotRefuelingRate)
        #expect(world.components[DepotServiceComponent.self][entity.id]?.deliveredOre == 0)
        #expect(world.components[DisplayNameComponent.self][entity.id]?.value == state.displayName)
        #expect(world.components[FuelComponent.self][entity.id]?.capacity == state.fuelCapacity)
        #expect(world.components[FuelComponent.self][entity.id]?.remaining == state.fuelRemaining)
        #expect(world.components[GravityReceiverComponent.self][entity.id] != nil)
        #expect(world.components[GravitySourceComponent.self][entity.id]?.gravitationalParameter == state.gravitationalParameter)
        #expect(world.components[InteractionComponent.self][entity.id]?.interactionRange == state.interactionRange)
        #expect(world.components[MassComponent.self][entity.id]?.dryMass == state.dryMass)
        #expect(world.components[MineableComponent.self][entity.id]?.miningRate == state.miningRate)
        #expect(world.components[ContactConsumptionComponent.self][entity.id] != nil)
        #expect(world.components[ContactDamageComponent.self][entity.id]?.amount.rawValue == state.contactDamage)
        #expect(world.components[HealthComponent.self][entity.id]?.health.rawValue == state.health)
        #expect(world.components[OwnershipComponent.self][entity.id]?.ownerEntityID == state.ownerEntityID)
        #expect(world.components[LifetimeComponent.self][entity.id]?.remainingLifetime == state.lifetime)
        #expect(world.components[MissileLauncherComponent.self][entity.id]?.speed == state.missileSpeed)
        #expect(world.components[MissileLauncherComponent.self][entity.id]?.lifetime == state.missileLifetime)
        #expect(world.components[MissileLauncherComponent.self][entity.id]?.radius == state.missileRadius)
        #expect(world.components[MotionComponent.self][entity.id] != nil)
        #expect(world.components[OrbitCircularizationAutopilotComponent.self][entity.id] == .idle)
        #expect(world.components[OrbitPrimaryComponent.self][entity.id]?.primaryEntityID == state.orbitPrimaryID)
        #expect(world.components[OrbitalRailComponent.self][entity.id] == nil)
        #expect(world.components[OreDepositComponent.self][entity.id]?.remainingOre == state.remainingOre)
        #expect(world.components[PlayerControlComponent.self][entity.id]?.translation == .zero)
        #expect(world.components[PlayerControlComponent.self][entity.id]?.interactionState == .inactive)
        #expect(world.components[PlayerControlComponent.self][entity.id]?.isFireRequested == false)
        #expect(world.components[PositionComponent.self][entity.id]?.position == state.position)
        #expect(world.components[PreviousPositionComponent.self][entity.id]?.position == state.position)
        #expect(world.components[PropulsionComponent.self][entity.id]?.maximumThrust == state.maximumThrust)
        #expect(world.components[PropulsionComponent.self][entity.id]?.exhaustVelocity == state.exhaustVelocity)
        #expect(world.components[RenderableComponent.self][entity.id]?.meshID == state.meshID)
        #expect(world.components[RenderableComponent.self][entity.id]?.materialID == state.materialID)
        #expect(world.components[RotationComponent.self][entity.id]?.rotation.vector == state.rotation?.vector)
        #expect(world.components[ScaleComponent.self][entity.id]?.scale == state.scale)
        #expect(world.components[SelectableComponent.self][entity.id]?.selectionState == .selected)
        #expect(world.components[SelectionBoundsComponent.self][entity.id]?.radius == state.selectionRadius)
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
        #expect(world.components[DestructibleComponent.self][entity.id] == nil)
        #expect(world.components[DestructibleComponent.self].entities == [primary.id])
        #expect(world.components[AngularMotionAccumulatorComponent.self][entity.id] == nil)
        #expect(world.components[AngularVelocityComponent.self][entity.id] == nil)
        #expect(world.components[CargoComponent.self][entity.id] == nil)
        #expect(world.components[CollisionBodyComponent.self][entity.id] == nil)
        #expect(world.components[DepotServiceComponent.self][entity.id] == nil)
        #expect(world.components[DisplayNameComponent.self][entity.id] == nil)
        #expect(world.components[FuelComponent.self][entity.id] == nil)
        #expect(world.components[GravityReceiverComponent.self][entity.id] == nil)
        #expect(world.components[GravitySourceComponent.self][entity.id] == nil)
        #expect(world.components[InteractionComponent.self][entity.id] == nil)
        #expect(world.components[MassComponent.self][entity.id] == nil)
        #expect(world.components[MineableComponent.self][entity.id] == nil)
        #expect(world.components[ContactConsumptionComponent.self][entity.id] == nil)
        #expect(world.components[ContactDamageComponent.self][entity.id] == nil)
        #expect(world.components[HealthComponent.self][entity.id] == nil)
        #expect(world.components[OwnershipComponent.self][entity.id] == nil)
        #expect(world.components[LifetimeComponent.self][entity.id] == nil)
        #expect(world.components[MissileLauncherComponent.self][entity.id] == nil)
        #expect(world.components[MotionComponent.self][entity.id] == nil)
        #expect(world.components[OrbitCircularizationAutopilotComponent.self][entity.id] == nil)
        #expect(world.components[OrbitPrimaryComponent.self][entity.id] == nil)
        #expect(world.components[OrbitalRailComponent.self][entity.id] == nil)
        #expect(world.components[OreDepositComponent.self][entity.id] == nil)
        #expect(world.components[PlayerControlComponent.self][entity.id] == nil)
        #expect(world.components[PositionComponent.self][entity.id] == nil)
        #expect(world.components[PreviousPositionComponent.self][entity.id] == nil)
        #expect(world.components[PropulsionComponent.self][entity.id] == nil)
        #expect(world.components[RenderableComponent.self][entity.id] == nil)
        #expect(world.components[RotationComponent.self][entity.id] == nil)
        #expect(world.components[ScaleComponent.self][entity.id] == nil)
        #expect(world.components[SelectableComponent.self][entity.id] == nil)
        #expect(world.components[SelectionBoundsComponent.self][entity.id] == nil)
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
        #expect(world.components[OrbitalRailComponent.self][asteroid.id] != nil)

        #expect(world.destroy(asteroid.id))

        #expect(world.components[OrbitalRailComponent.self][asteroid.id] == nil)
        #expect(world.components[PositionComponent.self][asteroid.id] == nil)
        #expect(world.components[PreviousPositionComponent.self][asteroid.id] == nil)
        #expect(world.components[CollisionBodyComponent.self][asteroid.id] == nil)
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
        #expect(world.components[DestructibleComponent.self].entities == [survivor.id])
        #expect(world.components[DestructibleComponent.self][survivor.id]?.state == .active)
        #expect(world.components[PositionComponent.self].entities == [survivor.id])
        #expect(world.selectedEntityID == survivor.id)
        #expect(world.components[SelectableComponent.self][survivor.id]?.selectionState == .selected)
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
        #expect(world.components[DestructibleComponent.self].entities == [entity.id])
        #expect(world.components[DestructibleComponent.self][entity.id]?.state == .active)
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
        #expect(world.components[SelectableComponent.self][entity.id]?.selectionState == .selected)
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
        #expect(world.components[SelectableComponent.self][first.id]?.selectionState == .unselected)
        #expect(world.components[SelectableComponent.self][second.id]?.selectionState == .selected)

        #expect(world.select(nil))
        #expect(world.selectedEntityID == nil)
        #expect(world.components[SelectableComponent.self][second.id]?.selectionState == .unselected)
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
