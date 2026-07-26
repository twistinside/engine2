/// Immutable recipe for constructing a caller-driven Simulation topology.
///
/// Manual configurations have no Input Runtime or cadence driver. A debugger,
/// test, turn-based host, or future tool coordinator advances the resulting
/// assembly only through the Simulation Runtime's exact capability.
nonisolated struct ManualConfiguration: Equatable, Sendable {
    /// Constructs an initially idle manual assembly with a fresh Simulation
    /// session identity.
    @MainActor
    func makeAssembly(gameContent: BasicGameContent) -> ManualAssembly {
        makeAssembly(
            gameContent: gameContent,
            sessionID: SimulationSessionID()
        )
    }

    /// Constructs an initially idle manual assembly with a caller-supplied
    /// Simulation identity for restoration or external correlation.
    @MainActor
    func makeAssembly(gameContent: BasicGameContent, sessionID: SimulationSessionID) -> ManualAssembly {
        let simulationRuntime = SimulationRuntime(
            worldBuilder: gameContent.worldBuilder,
            configuration: gameContent.simulationConfiguration,
            inputBaseline: nil,
            sessionID: sessionID
        )
        return ManualAssembly(simulationRuntime: simulationRuntime)
    }
}
