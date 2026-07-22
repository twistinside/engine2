/// Owns exact fixed-step execution and ordered systems against one World.
///
/// Elapsed-time accumulation remains only for the unused legacy `update` path;
/// configured App cadence belongs to `RealtimeAdvanceDriver`.
final class Engine {
    private let fixedTimeStepSeconds: Float

    private(set) var accumulatedTime: Duration = .zero
    private var alwaysSystems: [any PSystem]
    private var simulationSystems: [any PSystem]
    private var pendingInputSnapshot: InputSnapshot?

    let fixedTimeStep: Duration

    private(set) var completedTick: SimulationTick
    /// Legacy real-time pause policy used only by `update(deltaTime:inputSnapshot:)`.
    /// Explicit `step(inputSnapshot:)` calls always execute a complete schedule.
    var isSimulationRunning = true
    private(set) var world: World

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
        self.completedTick = .zero
        self.fixedTimeStep = fixedTimeStep
        self.fixedTimeStepSeconds = fixedTimeStep.seconds
        self.alwaysSystems = alwaysSystems
        self.simulationSystems = systems
        self.pendingInputSnapshot = nil
    }

    /// Adds real frame time, then runs as many fixed simulation steps as fit.
    func update(
        deltaTime: Duration,
        inputSnapshot: InputSnapshot? = nil
    ) {
        // Retain the latest publication until a fixed step actually consumes
        // it. Polls shorter than one step must not discard input.
        retainLatestInputSnapshot(inputSnapshot)

        // Carry leftover wall-clock time forward until it reaches the step size.
        accumulatedTime += deltaTime

        // Advance simulation in deterministic fixed-size chunks.
        while accumulatedTime >= fixedTimeStep {
            stepForLegacyRealtimeUpdate()
            accumulatedTime -= fixedTimeStep
        }
    }

    /// Advances the world by one complete fixed simulation step.
    ///
    /// Unlike the legacy real-time `update` path, an explicit step is exact:
    /// both the always-running and simulation schedules execute regardless of
    /// `isSimulationRunning`.
    func step(inputSnapshot: InputSnapshot? = nil) {
        // Pending input belongs to the legacy elapsed-time path. An exact step
        // must consume only the value explicitly attributable to this request.
        pendingInputSnapshot = nil
        retainLatestInputSnapshot(inputSnapshot)

        performStep(includingSimulationSystems: true)
    }

    /// Preserves the existing real-time pause behavior while explicit
    /// advancement migrates to the complete `step(inputSnapshot:)` contract.
    private func stepForLegacyRealtimeUpdate() {
        performStep(includingSimulationSystems: isSimulationRunning)
    }

    private func performStep(includingSimulationSystems: Bool) {
        // Import raw input once, immediately before the fixed-step schedule.
        // Cleanup at the end of the always-running schedule prevents a catch-up
        // update from replaying transient motion on later steps.
        if let pendingInputSnapshot {
            world.input.ingest(pendingInputSnapshot)
            self.pendingInputSnapshot = nil
        }

        run(&alwaysSystems)

        if includingSimulationSystems {
            run(&simulationSystems)
        }

        // Exact steps reach this point after the complete schedule. The legacy
        // gated path intentionally retains its existing cursor behavior while
        // real-time pause policy is migrated out of Engine.
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
        accumulatedTime = .zero
        pendingInputSnapshot = nil
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
            systems[index].update(
                world: &world,
                deltaTime: fixedTimeStepSeconds
            )
        }
    }

    private func retainLatestInputSnapshot(_ snapshot: InputSnapshot?) {
        guard let snapshot else {
            return
        }

        if let pendingInputSnapshot,
           pendingInputSnapshot.revision >= snapshot.revision {
            return
        }

        pendingInputSnapshot = snapshot
    }
}
