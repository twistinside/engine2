/// Immutable recipe for constructing a caller-driven Simulation topology.
///
/// Manual configurations have no Input Runtime and start no polling task. A
/// debugger, test, turn-based host, or future tool coordinator advances the
/// resulting assembly only through the Simulation Runtime's exact capability.
nonisolated struct ManualConfiguration: Equatable, Sendable {
    let fixedTimeStep: Duration

    init(fixedTimeStep: Duration = .seconds(1.0 / 60.0)) {
        precondition(fixedTimeStep > .zero, "Manual simulation requires a positive fixed time step.")
        self.fixedTimeStep = fixedTimeStep
    }

    /// Constructs one isolated, initially idle manual assembly.
    @MainActor
    func makeAssembly(
        gameContent: BasicGameContent,
        sessionID: SimulationSessionID = SimulationSessionID()
    ) -> ManualAssembly {
        ManualAssembly(
            simulationRuntime: SimulationRuntime(
                worldBuilder: gameContent.worldBuilder,
                sessionID: sessionID,
                fixedTimeStep: fixedTimeStep
            )
        )
    }
}
