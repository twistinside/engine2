/// App-facing authoritative boundary for one Simulation session.
///
/// `SimulationRuntime` owns the policy for constructing and replacing the
/// active world, serializes exact advancement, and publishes completed state.
/// Cadence, input sampling, pause policy, and lifecycle coordination belong to
/// the App-owned configuration that drives its narrow capabilities.
final class SimulationRuntime: PSimulationAdvanceTarget, PSimulationPresentationSource {
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

    /// Exact committed position of the currently owned authoritative timeline.
    var currentCursor: SimulationCursor {
        SimulationCursor(sessionID: sessionID, tick: engine.completedTick)
    }

    init(
        worldBuilder: any PWorldBuilder = BasicWorldBuilder(),
        inputBaseline: InputSnapshot? = nil,
        sessionID: SimulationSessionID = SimulationSessionID()
    ) {
        self.worldBuilder = worldBuilder
        self.sessionID = sessionID
        let world = worldBuilder.buildWorld()
        if let inputBaseline {
            world.input.rebase(to: inputBaseline)
        }
        let engine = Engine(
            world: world,
            fixedTimeStep: Self.fixedTimeStep
        )
        self.engine = engine
        self.latestPresentationSnapshot = engine.world.presentationSnapshot(
            at: SimulationCursor(
                sessionID: sessionID,
                tick: engine.completedTick
            )
        )
    }

    /// Rebuilds the active world and starts a distinct authoritative session.
    ///
    /// A configuration with an input connection supplies its latest
    /// publication as a baseline. That restores held state without replaying
    /// cumulative transient motion from the preceding world.
    func rebuildWorld(inputBaseline: InputSnapshot? = nil) {
        sessionID = SimulationSessionID()
        engine.replaceWorld(
            with: worldBuilder.buildWorld(),
            inputBaseline: inputBaseline
        )
        publishPresentationSnapshot(at: engine.completedTick)
    }

    /// Replaces the current builder, optionally rebuilding the world immediately.
    func replaceWorldBuilder(
        _ worldBuilder: any PWorldBuilder,
        rebuildWorldImmediately: Bool = true,
        inputBaseline: InputSnapshot? = nil
    ) {
        self.worldBuilder = worldBuilder
        if rebuildWorldImmediately {
            rebuildWorld(inputBaseline: inputBaseline)
        }
    }

    /// Advances the Runtime by an exact number of complete fixed steps.
    ///
    /// Input is accepted only through the immutable assignment carried by the
    /// request and is applied once at the first requested tick boundary. The
    /// owning assembly is responsible for granting at most one caller effective
    /// advance authority at a time.
    nonisolated func advance(
        _ request: SimulationAdvanceRequest
    ) async -> SimulationAdvanceOutcome {
        await advanceSynchronously(request)
    }

    /// Performs one non-suspending batch inside the Runtime's serialized
    /// mutation domain. The nonisolated protocol witness above only transports
    /// the immutable request and result across that boundary.
    private func advanceSynchronously(
        _ request: SimulationAdvanceRequest
    ) -> SimulationAdvanceOutcome {
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

        let firstStepInput: InputSnapshot?
        switch request.inputAssignment {
        case .none:
            firstStepInput = nil

        case let .ingest(snapshot):
            firstStepInput = snapshot

        case let .rebase(snapshot):
            engine.world.input.rebase(to: snapshot)
            firstStepInput = nil

        case let .rebaseThenIngest(baseline, snapshot):
            // Install the route-transition baseline inside the same serialized
            // mutation boundary as the first step. The step then derives only
            // input published after that captured baseline.
            engine.world.input.rebase(to: baseline)
            firstStepInput = snapshot
        }

        for stepIndex in 0..<request.stepCount.rawValue {
            engine.step(
                inputSnapshot: stepIndex == 0 ? firstStepInput : nil
            )
        }

        let finalSnapshot = publishPresentationSnapshot(at: engine.completedTick)
        let result = SimulationAdvanceResult(
            initialCursor: initialCursor,
            finalCursor: currentCursor,
            completedStepCount: SimulationCompletedStepCount(
                rawValue: request.stepCount.rawValue
            ),
            finalPresentationSnapshot: finalSnapshot
        )

        return .completed(result)
    }

    /// Replaces the latest-value slot only after the engine completes a fixed step.
    @discardableResult
    private func publishPresentationSnapshot(
        at tick: SimulationTick
    ) -> SimulationPresentationSnapshot {
        let snapshot = engine.world.presentationSnapshot(
            at: SimulationCursor(sessionID: sessionID, tick: tick)
        )
        latestPresentationSnapshot = snapshot
        return snapshot
    }
}
