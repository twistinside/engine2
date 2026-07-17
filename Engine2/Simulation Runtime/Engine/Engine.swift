//
//  Engine.swift
//  Engine2
//
//  Created by Codex on 3/10/26.
//

/// Owns simulation orchestration: frame-time accumulation, fixed-step timing,
/// and ordered system execution against the world state.
final class Engine {
    private let fixedTimeStepSeconds: Float

    private(set) var accumulatedTime: Duration = .zero
    private var alwaysSystems: [any PSystem]
    private var simulationSystems: [any PSystem]

    let fixedTimeStep: Duration

    var isSimulationRunning = true
    var world: World

    init(
        world: World = World(),
        fixedTimeStep: Duration = .seconds(1.0 / 60.0),
        alwaysSystems: [any PSystem] = [
            SInputMapping(),
            SCameraInput(),
            SInputHistory(),
            SInputCleanup()
        ],
        systems: [any PSystem] = [SAccelerationIntent(), SMovement(), SRotation()]
    ) {
        self.world = world
        self.fixedTimeStep = fixedTimeStep
        self.fixedTimeStepSeconds = fixedTimeStep.seconds
        self.alwaysSystems = alwaysSystems
        self.simulationSystems = systems
    }

    /// Adds real frame time, then runs as many fixed simulation steps as fit.
    func update(deltaTime: Duration) {
        // Carry leftover wall-clock time forward until it reaches the step size.
        accumulatedTime += deltaTime

        // Advance simulation in deterministic fixed-size chunks.
        while accumulatedTime >= fixedTimeStep {
            step()
            accumulatedTime -= fixedTimeStep
        }
    }

    /// Advances the world by one fixed simulation step.
    func step() {
        run(&alwaysSystems)

        if isSimulationRunning {
            run(&simulationSystems)
        }
    }

    /// Appends an always-running system to the execution pipeline in call order.
    func addAlwaysSystem(_ system: some PSystem) {
        alwaysSystems.append(system)
    }

    /// Appends a simulation-gated system to the execution pipeline in call order.
    func addSystem(_ system: some PSystem) {
        simulationSystems.append(system)
    }

    private func run(_ systems: inout [any PSystem]) {
        for index in systems.indices {
            // Pull the existential out, mutate it, then store it back so stateful
            // systems can preserve any internal state across steps.
            var system = systems[index]
            system.update(world: &world, deltaTime: fixedTimeStepSeconds)
            systems[index] = system
        }
    }
}
