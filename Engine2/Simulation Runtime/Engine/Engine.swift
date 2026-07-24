/// Owns exact fixed-step execution and one ordered system schedule against a World.
///
/// `Engine` does not sample clocks, accumulate elapsed time, or implement pause
/// policy. Every call to ``step(inputSnapshot:)`` is one complete Simulation
/// step. Production construction supplies ``SimulationRuntime/fixedTimeStep``;
/// the duration remains injectable here only for focused system integration
/// tests below the Runtime boundary.
final class Engine {
    private let fixedTimeStepSeconds: Float
    private var systems: [any PSystem]

    let fixedTimeStep: Duration

    private(set) var completedTick: SimulationTick
    private(set) var world: World

    init(
        world: World = World(),
        fixedTimeStep: Duration,
        systems: [any PSystem] = [
            SInputHistory(),
            SInputCleanup(),
            SAccelerationIntent(),
            SMovement(),
            SRotation()
        ]
    ) {
        precondition(
            fixedTimeStep > .zero,
            "Engine requires a positive fixed time step."
        )
        self.world = world
        self.completedTick = .zero
        self.fixedTimeStep = fixedTimeStep
        self.fixedTimeStepSeconds = fixedTimeStep.seconds
        self.systems = systems
    }

    /// Advances the world by one complete fixed simulation step.
    func step(inputSnapshot: InputSnapshot? = nil) {
        if let inputSnapshot {
            world.input.ingest(inputSnapshot)
        }

        run(&systems)
        completedTick = completedTick.advanced()
    }

    /// Installs a newly constructed world and begins a new tick timeline.
    func replaceWorld(
        with world: World,
        inputBaseline: InputSnapshot? = nil
    ) {
        self.world = world
        if let inputBaseline {
            self.world.input.rebase(to: inputBaseline)
        }
        completedTick = .zero
    }

    /// Appends a system to the complete execution pipeline in call order.
    func addSystem(_ system: some PSystem) {
        systems.append(system)
    }

    private func run(_ systems: inout [any PSystem]) {
        for index in systems.indices {
            systems[index].update(
                world: &world,
                deltaTime: fixedTimeStepSeconds
            )
        }
    }
}
