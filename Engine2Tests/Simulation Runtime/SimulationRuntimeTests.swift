//
//  SimulationRuntimeTests.swift
//  Engine2Tests
//
//  Created by Codex on 3/17/26.
//

import Testing
@testable import Engine2

struct SimulationRuntimeTests {
    @Test @MainActor func initBuildsEngineWorldFromBuilder() async throws {
        let builder = TestWorldBuilder(position: SIMD3<Float>(3, 4, 5))

        let simulation = SimulationRuntime(worldBuilder: builder)

        let entity = try #require(simulation.world.positionComponents.entities.first)
        #expect(simulation.world.positionComponents[entity]?.position == SIMD3<Float>(3, 4, 5))
        #expect(simulation.state.fixedTimeStep == .seconds(1.0 / 60.0))
        #expect(simulation.state.isRunning == false)
    }

    @Test @MainActor func rebuildWorldReplacesEngineWorldUsingStoredBuilder() async throws {
        let builder = IncrementingWorldBuilder()

        let simulation = SimulationRuntime(worldBuilder: builder)
        let firstWorld = simulation.world
        let firstEntity = try #require(firstWorld.positionComponents.entities.first)

        #expect(firstWorld.positionComponents[firstEntity]?.position == SIMD3<Float>(1, 0, 0))
        #expect(builder.buildCount == 1)

        simulation.rebuildWorld()

        let secondEntity = try #require(simulation.world.positionComponents.entities.first)

        #expect(builder.buildCount == 2)
        #expect(simulation.world !== firstWorld)
        #expect(simulation.world.positionComponents[secondEntity]?.position == SIMD3<Float>(2, 0, 0))
    }

    @Test @MainActor func startAndStopDriveExposedState() async throws {
        let simulation = SimulationRuntime(
            worldBuilder: TestWorldBuilder(position: .zero),
            pollInterval: .seconds(60)
        )

        #expect(simulation.state.isRunning == false)

        simulation.start()
        #expect(simulation.state.isRunning == true)

        simulation.stop()
        #expect(simulation.state.isRunning == false)
    }
}

private struct TestWorldBuilder: PWorldBuilder {
    let position: SIMD3<Float>

    func buildWorld() -> World {
        let world = World()
        _ = Ball(in: world, position: position)
        return world
    }
}

private final class IncrementingWorldBuilder: PWorldBuilder {
    private(set) var buildCount = 0

    func buildWorld() -> World {
        buildCount += 1

        let world = World()
        _ = Ball(in: world, position: SIMD3<Float>(Float(buildCount), 0, 0))
        return world
    }
}
