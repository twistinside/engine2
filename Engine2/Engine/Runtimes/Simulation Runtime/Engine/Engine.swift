/// Owns exact fixed-step execution and one ordered system schedule against a World.
///
/// `Engine` does not sample clocks, accumulate elapsed time, or implement pause
/// policy. Every call to ``step(inputSnapshot:)`` is one complete Simulation
/// step. Production construction supplies ``SimulationRuntime/fixedTimeStep``;
/// the duration remains injectable here only for focused system integration
/// tests below the Runtime boundary.
final class Engine {
    private let fixedTimeStepSeconds: Double
    private var systems: [any System]

    let fixedTimeStep: Duration

    private(set) var completedTick: SimulationTick
    private(set) var world: World

    /// Constructs the invariant production schedule from one validated Simulation policy.
    convenience init(
        world: World,
        fixedTimeStep: Duration,
        configuration: SimulationConfiguration,
        behavior: any SimulationBehavior = StandardSimulationBehavior()
    ) {
        let behaviorSchedule = behavior.makeSystemSchedule()
        self.init(
            world: world,
            fixedTimeStep: fixedTimeStep,
            systems:
            behaviorSchedule.inputConsumption +
            [
                CameraInputSystem(
                    target: configuration.cameraOrbitTarget,
                    orbitAxis: configuration.cameraOrbitAxis,
                    minimumRadius: configuration.minimumCameraOrbitRadius,
                    maximumRadius: configuration.maximumCameraOrbitRadius
                ),
            ] +
            behaviorSchedule.worldPreparation +
            behaviorSchedule.forceContribution +
            [
                AccelerationIntentSystem(),
                MovementSystem(),
                RotationSystem(),
            ] +
            behaviorSchedule.postMovement +
            behaviorSchedule.prePresentation +
            [
                InputCleanupSystem(),
            ]
        )
    }

    /// Constructs an Engine with a complete injected schedule for focused integration tests.
    init(
        world: World,
        fixedTimeStep: Duration,
        systems: [any System]
    ) {
        precondition(fixedTimeStep > .zero, "Engine requires a positive fixed time step.")
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
    func replaceWorld(with world: World, inputBaseline: InputSnapshot?) {
        self.world = world
        if let inputBaseline {
            self.world.input.rebase(to: inputBaseline)
        }
        completedTick = .zero
    }

    private func run(_ systems: inout [any System]) {
        for index in systems.indices {
            systems[index].update(
                world: &world,
                deltaTime: fixedTimeStepSeconds
            )
        }
    }
}
