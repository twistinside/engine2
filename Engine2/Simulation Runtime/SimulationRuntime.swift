//
//  SimulationRuntime.swift
//  Engine2
//
//  Created by Codex on 3/17/26.
//

import Observation

/// App-facing lifecycle boundary for the simulation runtime.
///
/// `SimulationRuntime` owns the policy for constructing and replacing the
/// active world. `Engine` remains the deterministic inner mechanism and owns
/// the invariant system schedule.
@MainActor
@Observable
final class SimulationRuntime {
    /// Minimal session state intended for SwiftUI and other presentation code.
    struct State {
        var fixedTimeStep: Duration
        var isLoopRunning = false
        var isRunning = false
    }

    @ObservationIgnored
    private(set) var worldBuilder: any PWorldBuilder

    @ObservationIgnored
    let engine: Engine

    @ObservationIgnored
    private let simulationLoop: SimulationLoop

    private(set) var state: State

    var world: World {
        engine.world
    }

    init(
        worldBuilder: any PWorldBuilder = BasicWorldBuilder(),
        fixedTimeStep: Duration = .seconds(1.0 / 60.0),
        pollInterval: Duration? = nil,
        clockFactory: @escaping SimulationLoop.ClockFactory = { SystemClock() },
        sleeper: @escaping SimulationLoop.Sleeper = { deadline in
            try await SuspendingClock().sleep(until: deadline)
        }
    ) {
        self.worldBuilder = worldBuilder
        let engine = Engine(
            world: worldBuilder.buildWorld(),
            fixedTimeStep: fixedTimeStep
        )
        self.engine = engine
        engine.isSimulationRunning = false
        self.state = State(fixedTimeStep: fixedTimeStep)

        let simulationLoop = SimulationLoop(
            engine: engine,
            pollInterval: pollInterval,
            clockFactory: clockFactory,
            sleeper: sleeper
        )
        self.simulationLoop = simulationLoop
        simulationLoop.runningStateDidChange = { [weak self] isRunning in
            self?.state.isLoopRunning = isRunning
        }
    }

    /// Rebuilds the active world from the current builder and swaps it into the engine.
    func rebuildWorld() {
        engine.world = worldBuilder.buildWorld()
    }

    /// Replaces the current builder, optionally rebuilding the world immediately.
    func replaceWorldBuilder(
        _ worldBuilder: any PWorldBuilder,
        rebuildWorldImmediately: Bool = true
    ) {
        self.worldBuilder = worldBuilder
        if rebuildWorldImmediately {
            rebuildWorld()
        }
    }

    /// Starts the session's polling loop if it is not already active.
    func start() {
        resumeSimulation()
        simulationLoop.start()
    }

    /// Stops the session's polling loop if it is active.
    func stop() {
        pauseSimulation()
        simulationLoop.stop()
    }

    /// Enables simulation systems while leaving the app-owned loop running.
    func resumeSimulation() {
        engine.isSimulationRunning = true
        state.isRunning = true
        simulationLoop.start()
    }

    /// Disables simulation systems while always-running input/tool systems continue.
    func pauseSimulation() {
        engine.isSimulationRunning = false
        state.isRunning = false
    }

    func handleInput(_ event: InputEvent) {
        engine.world.input.apply(event)
    }
}
