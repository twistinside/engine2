/// Immutable recipe for constructing a caller-driven Simulation topology.
///
/// Manual configurations have no Input Runtime or cadence driver. A debugger,
/// test, turn-based host, or future tool coordinator advances the resulting
/// assembly only through the Simulation Runtime's exact capability.
nonisolated struct ManualConfiguration: Equatable, Sendable {
    /// Constructs one isolated, initially idle manual assembly.
    @MainActor
    func makeAssembly(
        gameContent: BasicGameContent,
        sessionID: SimulationSessionID = SimulationSessionID()
    ) -> ManualAssembly {
        ManualAssembly(
            simulationRuntime: SimulationRuntime(
                worldBuilder: gameContent.worldBuilder,
                sessionID: sessionID
            )
        )
    }
}
