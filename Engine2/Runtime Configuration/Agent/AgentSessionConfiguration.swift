/// Immutable recipe for a live-process idempotent agent capture topology.
///
/// The value carries explicit Render and retention policy for assembly
/// construction. This is deliberately not an MCP Runtime: transport, request
/// DTOs, structured inspection, semantic controls, and durable replay remain
/// future work.
nonisolated struct AgentSessionConfiguration: Equatable, Sendable {
    let renderLimits: OffscreenRenderLimits
    let sessionLimits: AgentSessionLimits

    /// Constructs one closed agent assembly with fresh agent and Simulation
    /// session identities.
    @MainActor
    func makeAssembly(gameContent: BasicGameContent) throws -> AgentSessionAssembly {
        try makeAssembly(
            gameContent: gameContent,
            agentSessionID: AgentSessionID(),
            simulationSessionID: SimulationSessionID()
        )
    }

    /// Constructs one closed agent assembly with caller-supplied identities for
    /// restoration or external correlation.
    @MainActor
    func makeAssembly(
        gameContent: BasicGameContent,
        agentSessionID: AgentSessionID,
        simulationSessionID: SimulationSessionID
    ) throws -> AgentSessionAssembly {
        try AgentSessionAssembly(
            gameContent: gameContent,
            configuration: self,
            agentSessionID: agentSessionID,
            simulationSessionID: simulationSessionID
        )
    }
}
