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
        #expect(Set(world.lifecycleComponents.entities) == Set(world.registeredEntities.map(\.id)))
        #expect(world.lifecycleComponents.dense.allSatisfy { $0.state == .active })
        let originalAsteroids = Set(world.oreDepositComponents.entities)
        let depot = try #require(world.depotServiceComponents.entities.first)
        let skiff = try #require(world.selectedEntityID)
        input.receive(.keyDown(KeyboardKey(keyCode: 46)))
        input.receive(.keyUp(KeyboardKey(keyCode: 46)))

        engine.step(inputSnapshot: input.latestInputSnapshot)

        let missile = try #require(world.contactConsumptionComponents.entities.first)
        #expect(world.contactConsumptionComponents.entities.count == 1)
        #expect(world.entity(for: missile) is Missile)
        #expect(world.ownershipComponents[missile]?.ownerEntityID == skiff)
        #expect(world.renderableComponents[missile] != nil)
        #expect(world.registeredEntities.count == 10)
        #expect(world.lifecycleComponents[missile]?.state == .active)

        for _ in 0..<300 {
            engine.step(inputSnapshot: input.latestInputSnapshot)
        }

        #expect(world.contactConsumptionComponents.entities.isEmpty)
        #expect(world.entity(for: missile) == nil)
        #expect(world.registeredEntities.count == 8)
        #expect(world.lifecycleComponents[missile] == nil)
        #expect(Set(world.lifecycleComponents.entities) == Set(world.registeredEntities.map(\.id)))
        let removedAsteroids = originalAsteroids.subtracting(world.oreDepositComponents.entities)
        #expect(removedAsteroids.count == 1)
        #expect(world.entity(for: depot) != nil)
        #expect(world.collisionBodyComponents[depot] != nil)
        #expect(world.depotServiceComponents[depot] != nil)
        #expect(world.orbitalRailComponents[depot] != nil)
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
        let starID = try #require(world.gravitySourceComponents.entities.first)
        let star = try #require(world.entity(for: starID))
        #expect(world.lifecycleComponents.update(for: starID) { $0.state = .pendingRemoval })

        engine.step()

        #expect(star.lifecycleState == nil)
        #expect(world.entity(for: starID) == nil)
        #expect(world.gravitySourceComponents.entities.isEmpty)
        let railIDs = world.orbitalRailComponents.entities
        let retainedRails = world.orbitalRailComponents.dense
        let retainedPositions = railIDs.map { world.positionComponents[$0] }
        #expect(railIDs.count == 7)

        engine.step()

        #expect(engine.completedTick == SimulationTick(rawValue: 2))
        #expect(world.orbitalRailComponents.entities == railIDs)
        #expect(world.orbitalRailComponents.dense == retainedRails)
        #expect(railIDs.map { world.positionComponents[$0] } == retainedPositions)
        #expect(world.registeredEntities.count == 8)
        #expect(world.positionComponents.dense.allSatisfy { $0.position.isFinite })
        #expect(world.motionComponents.dense.allSatisfy { $0.velocity.isFinite })
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
        let asteroid = try #require(world.oreDepositComponents.entities.first)
        #expect(world.select(asteroid))
        input.receive(.keyDown(KeyboardKey(keyCode: 46)))

        engine.step(inputSnapshot: input.latestInputSnapshot)
        #expect(world.contactConsumptionComponents.entities.isEmpty)

        #expect(world.select(skiff))
        engine.step()
        #expect(world.contactConsumptionComponents.entities.isEmpty)

        input.receive(.keyUp(KeyboardKey(keyCode: 46)))
        input.receive(.keyDown(KeyboardKey(keyCode: 46)))
        engine.step(inputSnapshot: input.latestInputSnapshot)
        #expect(world.contactConsumptionComponents.entities.count == 1)
    }
}
