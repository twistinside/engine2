/// Assembly-facing authoritative boundary for one Simulation session.
///
/// `SimulationRuntime` owns the policy for constructing and replacing the
/// active world, serializes exact advancement, and publishes completed state.
/// Cadence, input sampling, pause policy, and lifecycle coordination belong to
/// the assembly-selected configuration that drives its narrow capabilities.
final class SimulationRuntime: PSelectedEntitySource, PSimulationAdvanceTarget, PSimulationPresentationSource {
    /// The sole production duration represented by one completed Simulation tick.
    nonisolated static let fixedTimeStep: Duration = .seconds(1.0 / 60.0)

    private(set) var worldBuilder: any PWorldBuilder

    private let engine: Engine

    /// Identity of the uninterrupted authoritative timeline currently owned by
    /// this Runtime. Rebuilding the World begins a new session at tick zero.
    private(set) var sessionID: SimulationSessionID

    /// Latest completed publisher-owned value available to peer runtimes.
    private(set) var latestPresentationSnapshot: SimulationPresentationSnapshot

    var world: World {
        engine.world
    }

    /// Selected facade exposed without wider World or Simulation authority.
    var selectedEntity: Entity? {
        guard let selectedEntityID = world.selectedEntityID else {
            return nil
        }
        return world.entity(for: selectedEntityID)
    }

    /// Exact committed position of the currently owned authoritative timeline.
    var currentCursor: SimulationCursor {
        SimulationCursor(sessionID: sessionID, tick: engine.completedTick)
    }

    init(
        worldBuilder: any PWorldBuilder,
        configuration: SimulationConfiguration,
        behavior: any PSimulationBehavior = StandardSimulationBehavior(),
        inputBaseline: InputSnapshot?,
        sessionID: SimulationSessionID
    ) {
        self.worldBuilder = worldBuilder
        self.sessionID = sessionID
        let world = worldBuilder.buildWorld()
        if let inputBaseline {
            world.input.rebase(to: inputBaseline)
        }
        let engine = Engine(
            world: world,
            fixedTimeStep: Self.fixedTimeStep,
            configuration: configuration,
            behavior: behavior
        )
        self.engine = engine
        let initialCursor = SimulationCursor(
            sessionID: sessionID,
            tick: engine.completedTick
        )
        self.latestPresentationSnapshot = engine.world.presentationSnapshot(at: initialCursor)
    }

    /// Starts a fresh authoritative timeline for the supplied World recipe and
    /// optional Input publication baseline.
    ///
    /// Restored or externally correlated sessions use
    /// `init(worldBuilder:configuration:inputBaseline:sessionID:)` so identity selection
    /// remains explicit at their composition boundary.
    convenience init(
        worldBuilder: any PWorldBuilder,
        configuration: SimulationConfiguration,
        behavior: any PSimulationBehavior = StandardSimulationBehavior(),
        inputBaseline: InputSnapshot?
    ) {
        self.init(
            worldBuilder: worldBuilder,
            configuration: configuration,
            behavior: behavior,
            inputBaseline: inputBaseline,
            sessionID: SimulationSessionID()
        )
    }

    /// Rebuilds the active world and starts a distinct authoritative session.
    ///
    /// A configuration with an input connection supplies its latest
    /// publication as a baseline. That restores held state without replaying
    /// cumulative transient motion from the preceding world.
    func rebuildWorld(inputBaseline: InputSnapshot?) {
        sessionID = SimulationSessionID()
        engine.replaceWorld(
            with: worldBuilder.buildWorld(),
            inputBaseline: inputBaseline
        )
        publishPresentationSnapshot(at: engine.completedTick)
    }

    /// Replaces the builder used by the next explicitly requested world rebuild.
    func replaceWorldBuilder(_ worldBuilder: any PWorldBuilder) {
        self.worldBuilder = worldBuilder
    }

    /// Replaces the builder and immediately begins a new session from its world.
    func replaceWorldBuilderAndRebuild(_ worldBuilder: any PWorldBuilder, inputBaseline: InputSnapshot?) {
        self.worldBuilder = worldBuilder
        rebuildWorld(inputBaseline: inputBaseline)
    }

    /// Advances the Runtime by an exact number of complete fixed steps.
    ///
    /// Input and the optional focused maneuver are accepted only through the
    /// immutable request and imported once at its first tick boundary. The
    /// owning assembly grants at most one caller effective advance authority.
    nonisolated func advance(_ request: SimulationAdvanceRequest) async -> SimulationAdvanceOutcome {
        await advanceSynchronously(request)
    }

    /// Performs one non-suspending batch inside the Runtime's serialized
    /// mutation domain. The nonisolated protocol witness above only transports
    /// the immutable request and result across that boundary.
    private func advanceSynchronously(_ request: SimulationAdvanceRequest) -> SimulationAdvanceOutcome {
        let initialCursor = currentCursor

        if let expectedCursor = request.expectedCursor,
           expectedCursor != initialCursor {
            return .rejected(
                .cursorMismatch(
                    expected: expectedCursor,
                    current: initialCursor
                )
            )
        }

        let firstStepInput = prepareFirstStepInput(for: request.inputAssignment)
        runFixedSteps(
            request.stepCount,
            firstStepInput: firstStepInput,
            firstStepOrbitCircularizationCommand: request.orbitCircularizationCommand
        )

        return .completed(
            publishCompletedAdvanceResult(
                startingAt: initialCursor,
                stepCount: request.stepCount
            )
        )
    }

    /// Applies baseline policy and returns the snapshot assigned to the first tick.
    private func prepareFirstStepInput(for assignment: SimulationInputAssignment) -> InputSnapshot? {
        switch assignment {
        case .none:
            return nil

        case let .ingest(snapshot):
            return snapshot

        case let .rebase(snapshot):
            engine.world.input.rebase(to: snapshot)
            return nil

        case let .rebaseThenIngest(baseline, snapshot):
            // Install the route-transition baseline inside the same serialized
            // mutation boundary as the first step. The step then derives only
            // input published after that captured baseline.
            engine.world.input.rebase(to: baseline)
            return snapshot
        }
    }

    /// Runs the exact requested batch, applying assigned input only to its first tick.
    private func runFixedSteps(
        _ stepCount: SimulationStepCount,
        firstStepInput: InputSnapshot?,
        firstStepOrbitCircularizationCommand: OrbitCircularizationCommand?
    ) {
        for stepIndex in 0..<stepCount.rawValue {
            engine.world.orbitCircularizationCommand = stepIndex == 0
                ? firstStepOrbitCircularizationCommand
                : nil
            engine.step(
                inputSnapshot: stepIndex == 0 ? firstStepInput : nil
            )
        }
        engine.world.orbitCircularizationCommand = nil
    }

    /// Publishes the completed batch and forms its cursor-correlated result.
    private func publishCompletedAdvanceResult(
        startingAt initialCursor: SimulationCursor,
        stepCount: SimulationStepCount
    ) -> SimulationAdvanceResult {
        let finalSnapshot = publishPresentationSnapshot(at: engine.completedTick)
        return SimulationAdvanceResult(
            initialCursor: initialCursor,
            finalCursor: currentCursor,
            completedStepCount: SimulationCompletedStepCount(
                rawValue: stepCount.rawValue
            ),
            finalPresentationSnapshot: finalSnapshot
        )
    }

    /// Replaces the latest-value slot only after the engine completes a fixed step.
    @discardableResult
    private func publishPresentationSnapshot(at tick: SimulationTick) -> SimulationPresentationSnapshot {
        let cursor = SimulationCursor(sessionID: sessionID, tick: tick)
        let snapshot = engine.world.presentationSnapshot(at: cursor)
        latestPresentationSnapshot = snapshot
        return snapshot
    }
}
