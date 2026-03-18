//
//  Game.swift
//  Engine2
//
//  Created by Codex on 3/17/26.
//

/// App-facing orchestration above the simulation engine.
///
/// `Game` owns the policy for how a session gets its world: a builder creates
/// the starting world, and the same builder can be reused later to rebuild or
/// replace the active world inside the engine.
final class Game {
    private(set) var worldBuilder: any WorldBuilder

    let engine: Engine

    var world: World {
        engine.world
    }

    init(
        worldBuilder: any WorldBuilder = BasicWorldBuilder(),
        fixedTimeStep: Duration = .seconds(1.0 / 60.0),
        systems: [any System] = [SMovement(), SRotation()]
    ) {
        self.worldBuilder = worldBuilder
        self.engine = Engine(
            world: worldBuilder.buildWorld(),
            fixedTimeStep: fixedTimeStep,
            systems: systems
        )
    }

    /// Rebuilds the active world from the current builder and swaps it into the engine.
    func rebuildWorld() {
        engine.world = worldBuilder.buildWorld()
    }

    /// Replaces the current builder, optionally rebuilding the world immediately.
    func replaceWorldBuilder(
        _ worldBuilder: any WorldBuilder,
        rebuildWorldImmediately: Bool = true
    ) {
        self.worldBuilder = worldBuilder
        if rebuildWorldImmediately {
            rebuildWorld()
        }
    }
}
