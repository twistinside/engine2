/// Immutable recipe for a live-process idempotent agent capture topology.
///
/// This is deliberately not an MCP Runtime. It supplies the session semantics
/// a future authenticated transport needs while leaving transport, request DTOs,
/// structured inspection, semantic controls, and durable replay as future work.
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
        let offlineAssembly = try OfflineCaptureConfiguration(
            renderLimits: renderLimits
        ).makeAssembly(
            gameContent: gameContent,
            sessionID: simulationSessionID
        )
        let coordinator = AgentSessionCoordinator(
            sessionID: agentSessionID,
            initialCursor: offlineAssembly.initialCursor,
            limits: sessionLimits,
            captureTarget: offlineAssembly.captureTarget,
            initialRequestSequence: .first
        )

        return AgentSessionAssembly(
            sessionID: agentSessionID,
            initialCursor: offlineAssembly.initialCursor,
            offlineAssembly: offlineAssembly,
            coordinator: coordinator
        )
    }
}
