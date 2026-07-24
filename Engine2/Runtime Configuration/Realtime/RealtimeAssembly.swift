/// Owns the live Runtime instances and lifecycle ordering for real-time play.
///
/// One Input Runtime publishes latest input, one cadence driver translates wall
/// time into exact requests, one Simulation Runtime commits those requests, and
/// one screen controller owns output-specific viewpoint changes. The assembly
/// explicitly fans host input into the independently owned recipients; none of
/// those recipients discovers a peer through global state.
@MainActor
final class RealtimeAssembly: PInputEventSink {
    let inputRuntime: InputRuntime
    let simulationRuntime: SimulationRuntime
    let advanceDriver: RealtimeAdvanceDriver
    let screenViewpointController: ScreenViewpointController

    private var lifecycleGeneration: UInt64 = 0

    /// Whether user policy currently permits real-time Simulation progress.
    var isAdvancementEnabled: Bool {
        advanceDriver.isAdvancementEnabled
    }

    /// Whether the permitted policy currently has a live cadence task.
    var isAdvancementActive: Bool {
        advanceDriver.isAdvancementEnabled && advanceDriver.isRunning
    }

    /// Authority failure requiring an App-coordinated cursor transition.
    var advancementFault: RealtimeAdvanceDriverFault? {
        advanceDriver.fault
    }

    init(
        inputRuntime: InputRuntime,
        simulationRuntime: SimulationRuntime,
        advanceDriver: RealtimeAdvanceDriver,
        screenViewpointController: ScreenViewpointController
    ) {
        self.inputRuntime = inputRuntime
        self.simulationRuntime = simulationRuntime
        self.advanceDriver = advanceDriver
        self.screenViewpointController = screenViewpointController
    }

    /// Starts the publisher before the cadence connection.
    ///
    /// Starting a fresh driver run makes reactivation an explicit input-connection
    /// boundary. The driver captures that publication immediately, then carries
    /// later active input with it in the first enabled request.
    func start() {
        beginLifecycleTransition()
        inputRuntime.start()
        advanceDriver.start()
    }

    /// Stops the cadence connection before its publisher.
    ///
    /// The driver's advancement preference is retained, so app backgrounding
    /// never turns a deliberate user pause back on.
    func stop() async {
        let transition = beginLifecycleTransition()
        await advanceDriver.stopAndDrain()

        // A newer start owns lifecycle policy now. Do not let completion of an
        // older asynchronous stop shut down its Input publication session.
        guard lifecycleGeneration == transition else {
            return
        }

        inputRuntime.stop()
    }

    /// Pauses authoritative progress while Input collection remains live.
    func pauseAdvancement() {
        advanceDriver.pauseAdvancement()
    }

    /// Resumes progress from a captured Input baseline on the next request.
    func resumeAdvancement() {
        advanceDriver.resumeAdvancement()

        // A fault or unexpected sleeper failure can end cadence independently
        // of the user's desired playback policy. If this assembly is active,
        // resume also restores the task after policy recovery.
        if inputRuntime.isRunning,
           advanceDriver.fault == nil {
            advanceDriver.start()
        }
    }

    /// Reconstructs Simulation as one coordinated cursor and input-baseline cutover.
    func rebuildSimulation() async {
        let transition = beginLifecycleTransition()
        let wasRunning = advanceDriver.isRunning
        await advanceDriver.stopAndDrain()

        guard lifecycleGeneration == transition else {
            return
        }

        let inputBaseline = inputRuntime.latestInputSnapshot
        simulationRuntime.rebuildWorld(inputBaseline: inputBaseline)
        screenViewpointController.reset()
        advanceDriver.synchronize(
            to: simulationRuntime.currentCursor,
            inputBaseline: inputBaseline
        )

        if wasRunning {
            advanceDriver.start()
        }
    }

    /// Advances lifecycle identity so stale asynchronous completions cannot
    /// apply an older App-scene decision after a newer one.
    @discardableResult
    private func beginLifecycleTransition() -> UInt64 {
        precondition(
            lifecycleGeneration < .max,
            "Real-time assembly lifecycle generation exhausted."
        )
        lifecycleGeneration += 1
        return lifecycleGeneration
    }

    /// Routes one platform event to the recipients selected by this assembly.
    ///
    /// The Input Runtime retains canonical device state for future Simulation
    /// requests. The screen controller interprets only output-specific orbit
    /// and zoom gestures, so it can change presentation while Simulation is
    /// paused. This concrete fan-out is intentionally not a generic route graph.
    func receive(_ event: InputEvent) {
        guard inputRuntime.isRunning else {
            return
        }

        inputRuntime.receive(event)
        screenViewpointController.receive(
            event,
            defaultCamera: simulationRuntime.latestPresentationSnapshot.camera
        )
    }
}
