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
    private var systems: [any System]

    let fixedTimeStep: Duration

    var world: World

    init(
        world: World = World(),
        fixedTimeStep: Duration = .seconds(1.0 / 60.0),
        systems: [any System] = [SMovement(), SRotation()]
    ) {
        self.world = world
        self.fixedTimeStep = fixedTimeStep
        self.fixedTimeStepSeconds = fixedTimeStep.seconds
        self.systems = systems
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

    /// Samples real time from a clock, then feeds that delta into the fixed-step loop.
    func tick<C: Clock>(using clock: inout C) {
        update(deltaTime: clock.consumeDeltaTime())
    }

    /// Advances the world by one fixed simulation step.
    func step() {
        for index in systems.indices {
            // Pull the existential out, mutate it, then store it back so stateful
            // systems can preserve any internal state across steps.
            var system = systems[index]
            system.update(world: &world, deltaTime: fixedTimeStepSeconds)
            systems[index] = system
        }
    }

    /// Appends a system to the execution pipeline in call order.
    func addSystem(_ system: some System) {
        systems.append(system)
    }
}
