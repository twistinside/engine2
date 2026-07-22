/// Immutable recipe for constructing the application's current real-time topology.
///
/// The configuration carries policy values, while ``RealtimeAssembly`` owns the
/// live Runtime instances created from those values. Keeping construction here
/// gives other configurations a deliberate place to choose a different topology
/// without adding optional peers or mode switches to the real-time assembly.
nonisolated struct RealtimeConfiguration: Equatable, Sendable {
    let fixedTimeStep: Duration
    let pollInterval: Duration?

    init(
        fixedTimeStep: Duration = .seconds(1.0 / 60.0),
        pollInterval: Duration? = nil
    ) {
        precondition(fixedTimeStep > .zero, "Real-time simulation requires a positive fixed time step.")
        if let pollInterval {
            precondition(pollInterval > .zero, "Real-time polling requires a positive interval.")
        }

        self.fixedTimeStep = fixedTimeStep
        self.pollInterval = pollInterval
    }

    /// Constructs one isolated real-time Runtime Assembly from Game Content.
    @MainActor
    func makeAssembly(gameContent: BasicGameContent) -> RealtimeAssembly {
        let inputRuntime = InputRuntime()
        let simulationRuntime = SimulationRuntime(
            worldBuilder: gameContent.worldBuilder,
            inputSource: inputRuntime,
            fixedTimeStep: fixedTimeStep,
            pollInterval: pollInterval
        )

        return RealtimeAssembly(
            inputRuntime: inputRuntime,
            simulationRuntime: simulationRuntime
        )
    }
}
