//
//  Game.swift
//  Engine2
//
//  Created by Codex on 3/17/26.
//

import Observation

/// App-facing orchestration above the simulation engine.
///
/// `Game` owns the policy for how a session gets its world: a builder creates
/// the starting world, and the same builder can be reused later to rebuild or
/// replace the active world inside the engine.
@MainActor
@Observable
final class Game {
    /// Minimal session state intended for SwiftUI and other presentation code.
    struct State {
        var fixedTimeStep: Duration
        var isRunning = false
    }

    @ObservationIgnored
    private(set) var worldBuilder: any WorldBuilder

    @ObservationIgnored
    let engine: Engine

    @ObservationIgnored
    private let gameLoop: GameLoop

    private(set) var state: State

    var world: World {
        engine.world
    }

    init(
        worldBuilder: any WorldBuilder = BasicWorldBuilder(),
        fixedTimeStep: Duration = .seconds(1.0 / 60.0),
        systems: [any System] = [SAccelerationIntent(), SMovement(), SRotation()],
        pollInterval: Duration? = nil,
        clockFactory: @escaping GameLoop.ClockFactory = { SystemClock() },
        sleeper: @escaping GameLoop.Sleeper = { deadline in
            try await SuspendingClock().sleep(until: deadline)
        }
    ) {
        self.worldBuilder = worldBuilder
        let engine = Engine(
            world: worldBuilder.buildWorld(),
            fixedTimeStep: fixedTimeStep,
            systems: systems
        )
        self.engine = engine
        self.state = State(fixedTimeStep: fixedTimeStep)

        let gameLoop = GameLoop(
            engine: engine,
            pollInterval: pollInterval,
            clockFactory: clockFactory,
            sleeper: sleeper
        )
        self.gameLoop = gameLoop
        gameLoop.runningStateDidChange = { [weak self] isRunning in
            self?.state.isRunning = isRunning
        }
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

    /// Starts the session's polling loop if it is not already active.
    func start() {
        gameLoop.start()
    }

    /// Stops the session's polling loop if it is active.
    func stop() {
        gameLoop.stop()
    }
}
