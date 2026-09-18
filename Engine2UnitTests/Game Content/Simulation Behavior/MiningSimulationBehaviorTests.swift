import Testing
@testable import Engine2

struct MiningSimulationBehaviorTests {
    @Test func missilePressSpawnsOnceAndDestroysAnAsteroidInTheProductionSchedule() throws {
        let input = InputRuntime(mappingConfiguration: .miningGame)
        input.start()
        let world = MiningWorldBuilder().buildWorld()
        world.input.rebase(to: input.latestInputSnapshot)
        let engine = Engine(
            world: world,
            fixedTimeStep: SimulationRuntime.fixedTimeStep,
            configuration: .miningGame,
            behavior: MiningSimulationBehavior()
        )
        #expect(Set(world.components[DestructibleComponent.self].entities) == Set(world.registeredEntities.map(\.id)))
        #expect(world.components[DestructibleComponent.self].dense.allSatisfy { $0.state == .active })
        let originalAsteroids = Set(world.components[OreDepositComponent.self].entities)
        let depot = try #require(world.components[DepotServiceComponent.self].entities.first)
        let skiff = try #require(world.selectedEntityID)
        input.receive(.keyDown(KeyboardKey(keyCode: 46)))
        input.receive(.keyUp(KeyboardKey(keyCode: 46)))

        engine.step(inputSnapshot: input.latestInputSnapshot)

        let missile = try #require(world.components[ContactConsumptionComponent.self].entities.first)
        #expect(world.components[ContactConsumptionComponent.self].entities.count == 1)
        #expect(world.entity(for: missile) is Missile)
        #expect(world.components[OwnershipComponent.self][missile]?.ownerEntityID == skiff)
        #expect(world.components[RenderableComponent.self][missile] != nil)
        #expect(world.registeredEntities.count == 10)
        #expect(world.components[DestructibleComponent.self][missile]?.state == .active)

        for _ in 0..<300 {
            engine.step(inputSnapshot: input.latestInputSnapshot)
        }

        #expect(world.components[ContactConsumptionComponent.self].entities.isEmpty)
        #expect(world.entity(for: missile) == nil)
        #expect(world.registeredEntities.count == 8)
        #expect(world.components[DestructibleComponent.self][missile] == nil)
        #expect(Set(world.components[DestructibleComponent.self].entities) == Set(world.registeredEntities.map(\.id)))
        let removedAsteroids = originalAsteroids.subtracting(world.components[OreDepositComponent.self].entities)
        #expect(removedAsteroids.count == 1)
        #expect(world.entity(for: depot) != nil)
        #expect(world.components[CollisionBodyComponent.self][depot] != nil)
        #expect(world.components[DepotServiceComponent.self][depot] != nil)
        #expect(world.components[OrbitalRailComponent.self][depot] != nil)
        #expect(world.selectedEntityID == skiff)

        let snapshot = world.presentationSnapshot(
            at: SimulationCursor(sessionID: SimulationSessionID(), tick: engine.completedTick)
        )
        #expect(!snapshot.entityPresentations.contains { $0.id == missile || removedAsteroids.contains($0.id) })
        #expect(snapshot.entityPresentations.contains { $0.id == depot })
        #expect(snapshot.entityPresentations.count == 8)
    }

    @Test func removingTheStarPreservesOrphanedRailsOnTheFollowingTick() throws {
        let world = MiningWorldBuilder().buildWorld()
        let engine = Engine(
            world: world,
            fixedTimeStep: SimulationRuntime.fixedTimeStep,
            configuration: .miningGame,
            behavior: MiningSimulationBehavior()
        )
        let starID = try #require(world.components[GravitySourceComponent.self].entities.first)
        let star = try #require(world.entity(for: starID))
        #expect(world.components[DestructibleComponent.self].update(for: starID) { $0.state = .pendingRemoval })

        engine.step()

        #expect(star.lifecycleState == nil)
        #expect(world.entity(for: starID) == nil)
        #expect(world.components[GravitySourceComponent.self].entities.isEmpty)
        let railIDs = world.components[OrbitalRailComponent.self].entities
        let retainedRails = world.components[OrbitalRailComponent.self].dense
        let retainedPositions = railIDs.map { world.components[PositionComponent.self][$0] }
        #expect(railIDs.count == 7)

        engine.step()

        #expect(engine.completedTick == SimulationTick(rawValue: 2))
        #expect(world.components[OrbitalRailComponent.self].entities == railIDs)
        #expect(world.components[OrbitalRailComponent.self].dense == retainedRails)
        #expect(railIDs.map { world.components[PositionComponent.self][$0] } == retainedPositions)
        #expect(world.registeredEntities.count == 8)
        #expect(world.components[PositionComponent.self].dense.allSatisfy { $0.position.isFinite })
        #expect(world.components[MotionComponent.self].dense.allSatisfy { $0.velocity.isFinite })
    }

    @Test func firingRequiresASelectedLauncherAndDoesNotReplayAfterSelectionChanges() throws {
        let input = InputRuntime(mappingConfiguration: .miningGame)
        input.start()
        let world = MiningWorldBuilder().buildWorld()
        world.input.rebase(to: input.latestInputSnapshot)
        let engine = Engine(
            world: world,
            fixedTimeStep: SimulationRuntime.fixedTimeStep,
            configuration: .miningGame,
            behavior: MiningSimulationBehavior()
        )
        let skiff = try #require(world.selectedEntityID)
        let asteroid = try #require(world.components[OreDepositComponent.self].entities.first)
        #expect(world.select(asteroid))
        input.receive(.keyDown(KeyboardKey(keyCode: 46)))

        engine.step(inputSnapshot: input.latestInputSnapshot)
        #expect(world.components[ContactConsumptionComponent.self].entities.isEmpty)

        #expect(world.select(skiff))
        engine.step()
        #expect(world.components[ContactConsumptionComponent.self].entities.isEmpty)

        input.receive(.keyUp(KeyboardKey(keyCode: 46)))
        input.receive(.keyDown(KeyboardKey(keyCode: 46)))
        engine.step(inputSnapshot: input.latestInputSnapshot)
        #expect(world.components[ContactConsumptionComponent.self].entities.count == 1)
    }
}
