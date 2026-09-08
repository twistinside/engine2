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
        let originalAsteroids = Set(world.destructibleComponents.entities)
        let skiff = try #require(world.selectedEntityID)
        input.receive(.keyDown(KeyboardKey(keyCode: 46)))
        input.receive(.keyUp(KeyboardKey(keyCode: 46)))

        engine.step(inputSnapshot: input.latestInputSnapshot)

        let missile = try #require(world.missileComponents.entities.first)
        #expect(world.missileComponents.entities.count == 1)
        #expect(world.entity(for: missile) is Missile)
        #expect(world.missileComponents[missile]?.ownerEntityID == skiff)
        #expect(world.renderableComponents[missile] != nil)
        #expect(world.destructibleComponents.entities.count == 6)

        for _ in 0..<300 {
            engine.step(inputSnapshot: input.latestInputSnapshot)
        }

        #expect(world.missileComponents.entities.isEmpty)
        #expect(world.entity(for: missile) == nil)
        #expect(world.destructibleComponents.entities.count == 5)
        let destroyed = try #require(originalAsteroids.subtracting(world.destructibleComponents.entities).first)
        #expect(world.entity(for: destroyed) == nil)
        #expect(world.collisionBodyComponents[destroyed] == nil)
        #expect(world.oreDepositComponents[destroyed] == nil)
        #expect(world.orbitalRailComponents[destroyed] == nil)
        #expect(world.selectedEntityID == skiff)

        let snapshot = world.presentationSnapshot(
            at: SimulationCursor(sessionID: SimulationSessionID(), tick: engine.completedTick)
        )
        #expect(!snapshot.entityPresentations.contains { $0.id == missile || $0.id == destroyed })
        #expect(snapshot.entityPresentations.count == 8)
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
        let asteroid = try #require(world.destructibleComponents.entities.first)
        #expect(world.select(asteroid))
        input.receive(.keyDown(KeyboardKey(keyCode: 46)))

        engine.step(inputSnapshot: input.latestInputSnapshot)
        #expect(world.missileComponents.entities.isEmpty)

        #expect(world.select(skiff))
        engine.step()
        #expect(world.missileComponents.entities.isEmpty)

        input.receive(.keyUp(KeyboardKey(keyCode: 46)))
        input.receive(.keyDown(KeyboardKey(keyCode: 46)))
        engine.step(inputSnapshot: input.latestInputSnapshot)
        #expect(world.missileComponents.entities.count == 1)
    }
}
