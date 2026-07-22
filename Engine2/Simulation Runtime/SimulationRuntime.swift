import Observation

/// App-facing lifecycle boundary for the simulation runtime.
///
/// `SimulationRuntime` owns the policy for constructing and replacing the
/// active world. `Engine` remains the deterministic inner mechanism and owns
/// the invariant system schedule.
@MainActor
@Observable
final class SimulationRuntime: PSimulationAdvanceTarget, PSimulationPresentationSource {
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

    @ObservationIgnored
    private weak var inputSource: (any PInputSnapshotSource)?

    /// Identity of the uninterrupted authoritative timeline currently owned by
    /// this Runtime. Rebuilding the World begins a new session at tick zero.
    @ObservationIgnored
    private(set) var sessionID: SimulationSessionID

    /// Latest completed publisher-owned value available to peer runtimes.
    @ObservationIgnored
    private(set) var latestPresentationSnapshot: SimulationPresentationSnapshot

    private(set) var state: State

    var world: World {
        engine.world
    }

    /// Exact committed position of the currently owned authoritative timeline.
    var currentCursor: SimulationCursor {
        SimulationCursor(sessionID: sessionID, tick: engine.completedTick)
    }

    init(
        worldBuilder: any PWorldBuilder = BasicWorldBuilder(),
        inputSource: (any PInputSnapshotSource)? = nil,
        sessionID: SimulationSessionID = SimulationSessionID(),
        fixedTimeStep: Duration = .seconds(1.0 / 60.0),
        pollInterval: Duration? = nil,
        clockFactory: @escaping SimulationLoop.ClockFactory = { SystemClock() },
        sleeper: @escaping SimulationLoop.Sleeper = { deadline in
            try await SuspendingClock().sleep(until: deadline)
        }
    ) {
        self.worldBuilder = worldBuilder
        self.inputSource = inputSource
        self.sessionID = sessionID
        let world = worldBuilder.buildWorld()
        if let inputSnapshot = inputSource?.latestInputSnapshot {
            world.input.rebase(to: inputSnapshot)
        }
        let engine = Engine(
            world: world,
            fixedTimeStep: fixedTimeStep
        )
        self.engine = engine
        engine.isSimulationRunning = false
        self.latestPresentationSnapshot = SimulationPresentationSnapshot.capture(
            from: engine.world,
            at: SimulationCursor(
                sessionID: sessionID,
                tick: engine.completedTick
            )
        )
        self.state = State(fixedTimeStep: fixedTimeStep)

        let simulationLoop = SimulationLoop(
            engine: engine,
            inputSource: inputSource,
            pollInterval: pollInterval,
            clockFactory: clockFactory,
            sleeper: sleeper
        )
        self.simulationLoop = simulationLoop
        simulationLoop.runningStateDidChange = { [weak self] isRunning in
            self?.state.isLoopRunning = isRunning
        }
        simulationLoop.fixedStepsDidComplete = { [weak self] completedTick in
            self?.publishPresentationSnapshot(at: completedTick)
        }
    }

    /// Rebuilds the active world from the current builder and swaps it into the engine.
    func rebuildWorld() {
        sessionID = SimulationSessionID()
        engine.replaceWorld(
            with: worldBuilder.buildWorld(),
            inputBaseline: inputSource?.latestInputSnapshot
        )
        publishPresentationSnapshot(at: engine.completedTick)
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

    /// Advances an idle Runtime by an exact number of complete fixed steps.
    ///
    /// The legacy polling loop and this directed capability are mutually
    /// exclusive advance authorities. Input is accepted only through the
    /// immutable assignment carried by the request and is applied once at the
    /// first requested tick boundary.
    nonisolated func advance(
        _ request: SimulationAdvanceRequest
    ) async -> SimulationAdvanceOutcome {
        await MainActor.run {
            advanceSynchronously(request)
        }
    }

    /// Performs one non-suspending batch inside the Runtime's serialized
    /// mutation domain. The nonisolated protocol witness above only transports
    /// the immutable request and result across that boundary.
    private func advanceSynchronously(
        _ request: SimulationAdvanceRequest
    ) -> SimulationAdvanceOutcome {
        let initialCursor = currentCursor

        guard simulationLoop.isRunning == false else {
            return .rejected(.advanceAuthorityActive(current: initialCursor))
        }

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

    /// Replaces the latest-value slot only after the engine completes a fixed step.
    @discardableResult
    private func publishPresentationSnapshot(
        at tick: SimulationTick
    ) -> SimulationPresentationSnapshot {
        let snapshot = SimulationPresentationSnapshot.capture(
            from: engine.world,
            at: SimulationCursor(sessionID: sessionID, tick: tick)
        )
        latestPresentationSnapshot = snapshot
        return snapshot
    }
}
