//
//  GameTests.swift
//  Engine2Tests
//
//  Created by Codex on 3/17/26.
//

import Testing
@testable import Engine2

struct GameTests {
    @Test func initBuildsEngineWorldFromBuilder() async throws {
        let builder = TestWorldBuilder(position: SIMD3<Float>(3, 4, 5))

        let game = Game(worldBuilder: builder)

        let entity = try #require(game.world.positionComponents.entities.first)
        #expect(game.world.positionComponents[entity]?.position == SIMD3<Float>(3, 4, 5))
    }

    @Test func rebuildWorldReplacesEngineWorldUsingStoredBuilder() async throws {
        let builder = IncrementingWorldBuilder()

        let game = Game(worldBuilder: builder)
        let firstWorld = game.world
        let firstEntity = try #require(firstWorld.positionComponents.entities.first)

        #expect(firstWorld.positionComponents[firstEntity]?.position == SIMD3<Float>(1, 0, 0))
        #expect(builder.buildCount == 1)

        game.rebuildWorld()

        let secondEntity = try #require(game.world.positionComponents.entities.first)

        #expect(builder.buildCount == 2)
        #expect(game.world !== firstWorld)
        #expect(game.world.positionComponents[secondEntity]?.position == SIMD3<Float>(2, 0, 0))
    }
}

private struct TestWorldBuilder: WorldBuilder {
    let position: SIMD3<Float>

    func buildWorld() -> World {
        let world = World()
        _ = Ball(in: world, position: position)
        return world
    }
}

private final class IncrementingWorldBuilder: WorldBuilder {
    private(set) var buildCount = 0

    func buildWorld() -> World {
        buildCount += 1

        let world = World()
        _ = Ball(in: world, position: SIMD3<Float>(Float(buildCount), 0, 0))
        return world
    }
}
