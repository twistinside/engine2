import Testing
import simd
@testable import Engine2

struct WorldTests {
    private var completeInitialState: Entity.InitialState {
        let primary = EntityID(index: 100, generation: 3)
        return Entity.InitialState(
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
            cargo: CargoComponent(capacity: 20, ore: 3),
            collisionBody: CollisionBodyComponent(radius: 2, restitution: 0.35),
            depotService: DepotServiceComponent(
                unloadingRate: 4,
                refuelingRate: 5,
                deliveredOre: 6
            ),
            destructible: DestructibleComponent(),
            displayName: DisplayNameComponent(value: "Complete"),
            fuel: FuelComponent(capacity: 30, remaining: 7),
            gravityReceiver: GravityReceiverComponent(),
            gravitySource: GravitySourceComponent(gravitationalParameter: 40),
            interaction: InteractionComponent(interactionRange: 8),
            mass: MassComponent(dryMass: 50),
            mineable: MineableComponent(miningRate: 9),
            missile: MissileComponent(ownerEntityID: primary, remainingLifetime: 12),
            missileLauncher: MissileLauncherComponent(speed: 45, lifetime: 10, radius: 0.5),
            orbitPrimary: OrbitPrimaryComponent(primaryEntityID: primary),
            orbitalRail: OrbitalRailComponent(
                primaryEntityID: primary,
                radius: 60,
                angularSpeed: 0.1,
                phase: 0.2
            ),
            oreDeposit: OreDepositComponent(remainingOre: 70),
            playerControl: PlayerControlComponent(
                translation: SIMD2<Double>(0.5, -0.5),
                interactionState: .active,
                isFireRequested: false
            ),
            previousPosition: PreviousPositionComponent(position: SIMD3<Double>(-1, -2, -3)),
            propulsion: PropulsionComponent(maximumThrust: 80, exhaustVelocity: 90),
            renderable: RenderableInitialState(meshID: .ball, materialID: .goldMetal),
            selectionBounds: SelectionBoundsComponent(radius: 10)
        )
    }

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
            selectionBounds: SelectionBoundsComponent(radius: 2)
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
        let state = completeInitialState

        world.add(entity, from: state)

        #expect(world.angularMotionAccumulatorComponents[entity.id] != nil)
        #expect(world.angularVelocityComponents[entity.id] != nil)
        #expect(world.cargoComponents[entity.id] == state.cargo)
        #expect(world.collisionBodyComponents[entity.id] == state.collisionBody)
        #expect(world.depotServiceComponents[entity.id] == state.depotService)
        #expect(world.destructibleComponents[entity.id] == state.destructible)
        #expect(world.displayNameComponents[entity.id] == state.displayName)
        #expect(world.fuelComponents[entity.id] == state.fuel)
        #expect(world.gravityReceiverComponents[entity.id] == state.gravityReceiver)
        #expect(world.gravitySourceComponents[entity.id] == state.gravitySource)
        #expect(world.interactionComponents[entity.id] == state.interaction)
        #expect(world.massComponents[entity.id] == state.mass)
        #expect(world.mineableComponents[entity.id] == state.mineable)
        #expect(world.missileComponents[entity.id] == state.missile)
        #expect(world.missileLauncherComponents[entity.id] == state.missileLauncher)
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

    @Test func destroyRemovesEveryComponentAndLiveResourceReference() {
        let world = World()
        let entity = TestCompleteSpawnEntity(
            unregisteredID: world.reserveEntityID(),
            in: world
        )
        world.add(entity, from: completeInitialState)
        world.cameraFollowEntityID = entity.id
        world.orbitCircularizationCommand = OrbitCircularizationCommand(entityID: entity.id)

        #expect(world.destroy(entity.id))

        #expect(world.entity(for: entity.id) == nil)
        #expect(world.registeredEntities.isEmpty)
        #expect(world.selectedEntityID == nil)
        #expect(world.cameraFollowEntityID == nil)
        #expect(world.orbitCircularizationCommand == nil)
        #expect(world.angularMotionAccumulatorComponents[entity.id] == nil)
        #expect(world.angularVelocityComponents[entity.id] == nil)
        #expect(world.cargoComponents[entity.id] == nil)
        #expect(world.collisionBodyComponents[entity.id] == nil)
        #expect(world.depotServiceComponents[entity.id] == nil)
        #expect(world.destructibleComponents[entity.id] == nil)
        #expect(world.displayNameComponents[entity.id] == nil)
        #expect(world.fuelComponents[entity.id] == nil)
        #expect(world.gravityReceiverComponents[entity.id] == nil)
        #expect(world.gravitySourceComponents[entity.id] == nil)
        #expect(world.interactionComponents[entity.id] == nil)
        #expect(world.massComponents[entity.id] == nil)
        #expect(world.mineableComponents[entity.id] == nil)
        #expect(world.missileComponents[entity.id] == nil)
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
        let state = Entity.InitialState(selectionBounds: SelectionBoundsComponent(radius: 1))
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
                renderable: RenderableInitialState(meshID: .ball, materialID: .goldMetal)
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
            selectionBounds: SelectionBoundsComponent(radius: 1)
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
                selectionBounds: SelectionBoundsComponent(radius: 1)
            )
        )

        world.add(
            entity,
            from: Entity.InitialState(
                selectionBounds: SelectionBoundsComponent(radius: 1)
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
            selectionBounds: SelectionBoundsComponent(radius: 1)
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
    private final class TestSpawnEntity: Entity, Positionable, Scalable {}
    private final class TestMovableSpawnEntity: Entity, Movable {}
    private final class TestSelectableSpawnEntity: Entity, Selectable {}
    private final class TestRenderableSpawnEntity: Entity, Renderable {}
    private final class TestCompleteSpawnEntity: Entity, CargoCarrying, Collidable,
        DepotServicing, Destructible, DisplayNamed, Fueled, GravityAffected, GravitySource,
        LiveMass, Mineable, MissileLaunching, MissileProjectile, OrbitCircularizable,
        Orbiting, PlayerControlled, Propelled, Renderable, Rotatable, Scalable, Selectable {}
}
