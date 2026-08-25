/// Owns exact fixed-tick execution and one ordered system schedule against a World.
///
/// `Engine` does not sample clocks, accumulate elapsed time, or implement pause
/// policy. Every call to ``step(inputSnapshot:)`` is one complete Simulation
/// tick. Production construction supplies ``SimulationRuntime/fixedTimeStep``
/// as its nominal base interval and applies the selected Simulation time scale to the
/// interval systems receive. The duration remains injectable here only for
/// focused system integration tests below the Runtime boundary.
final class Engine {
    private let systemIntervalSeconds: Double
    private var systems: [any PSystem]

    let fixedTimeStep: Duration

    private(set) var completedTick: SimulationTick
    private(set) var world: World

    /// Constructs the invariant production schedule from one validated Simulation policy.
    convenience init(world: World, fixedTimeStep: Duration, configuration: SimulationConfiguration) {
        self.init(
            world: world,
            fixedTimeStep: fixedTimeStep,
            simulationTimeScale: configuration.simulationTimeScale,
            systems: Self.productionSystems(configuration: configuration)
        )
    }

    /// Constructs an Engine with a complete injected schedule for focused integration tests.
    convenience init(
        world: World,
        fixedTimeStep: Duration,
        systems: [any PSystem]
    ) {
        self.init(
            world: world,
            fixedTimeStep: fixedTimeStep,
            simulationTimeScale: .realTime,
            systems: systems
        )
    }

    private init(
        world: World,
        fixedTimeStep: Duration,
        simulationTimeScale: SimulationTimeScale,
        systems: [any PSystem]
    ) {
        precondition(fixedTimeStep > .zero, "Engine requires a positive fixed time step.")
        let systemIntervalSeconds = fixedTimeStep.seconds * simulationTimeScale.multiplier
        precondition(
            systemIntervalSeconds.isFinite && systemIntervalSeconds > 0,
            "Engine requires a finite positive scaled system interval."
        )
        self.world = world
        self.completedTick = .zero
        self.fixedTimeStep = fixedTimeStep
        self.systemIntervalSeconds = systemIntervalSeconds
        self.systems = systems
    }

    /// Advances the world by one complete fixed Simulation tick.
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

    /// Appends a system to the complete execution pipeline in call order.
    func addSystem(_ system: some PSystem) {
        systems.append(system)
    }

    private func run(_ systems: inout [any PSystem]) {
        for index in systems.indices {
            systems[index].update(
                world: &world,
                deltaTime: systemIntervalSeconds
            )
        }
    }

    private static func productionSystems(
        configuration: SimulationConfiguration
    ) -> [any PSystem] {
        [
            SInputMapping(
                pointerOrbitSensitivity: configuration.pointerOrbitSensitivity,
                scrollZoomSensitivity: configuration.scrollZoomSensitivity
            ),
            SCameraInput(
                target: configuration.cameraOrbitTarget,
                minimumRadius: configuration.minimumCameraOrbitRadius,
                maximumRadius: configuration.maximumCameraOrbitRadius
            ),
            SInputHistory(),
            SInputCleanup(),
            SAccelerationIntent(),
            SGravity(),
            SMovement(),
            SRotation()
        ]
    }
}
