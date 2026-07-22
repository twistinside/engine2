/// Immutable recipe for constructing the application's current real-time topology.
///
/// The configuration carries policy values, while ``RealtimeAssembly`` owns the
/// live Runtime instances created from those values. Keeping construction here
/// gives other configurations a deliberate place to choose a different topology
/// without adding optional peers or mode switches to the real-time assembly.
nonisolated struct RealtimeConfiguration: Equatable, Sendable {
    let fixedTimeStep: Duration
    let pollInterval: Duration?
    let catchUpPolicy: RealtimeCatchUpPolicy

    init(
        fixedTimeStep: Duration = .seconds(1.0 / 60.0),
        pollInterval: Duration? = nil,
        catchUpPolicy: RealtimeCatchUpPolicy = .interactive
    ) {
        precondition(fixedTimeStep > .zero, "Real-time simulation requires a positive fixed time step.")
        if let pollInterval {
            precondition(pollInterval > .zero, "Real-time polling requires a positive interval.")
        }

        self.fixedTimeStep = fixedTimeStep
        self.pollInterval = pollInterval
        self.catchUpPolicy = catchUpPolicy
    }

    /// Constructs one isolated real-time Runtime Assembly from Game Content.
    @MainActor
    func makeAssembly(gameContent: BasicGameContent) -> RealtimeAssembly {
        let inputRuntime = InputRuntime()
        let simulationRuntime = SimulationRuntime(
            worldBuilder: gameContent.worldBuilder,
            inputBaseline: inputRuntime.latestInputSnapshot,
            fixedTimeStep: fixedTimeStep
        )
        let advanceDriver = RealtimeAdvanceDriver(
            advanceTarget: simulationRuntime,
            inputSource: inputRuntime,
            initialCursor: simulationRuntime.currentCursor,
            fixedTimeStep: fixedTimeStep,
            pollInterval: pollInterval,
            catchUpPolicy: catchUpPolicy
        )
        let screenViewpointController = ScreenViewpointController()

        return RealtimeAssembly(
            inputRuntime: inputRuntime,
            simulationRuntime: simulationRuntime,
            advanceDriver: advanceDriver,
            screenViewpointController: screenViewpointController
        )
    }
}
