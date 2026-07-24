/// Immutable recipe for a live-process idempotent agent capture topology.
///
/// This is deliberately not an MCP Runtime. It supplies the session semantics
/// a future authenticated transport needs while leaving transport, request DTOs,
/// structured inspection, semantic controls, and durable replay as future work.
nonisolated struct AgentSessionConfiguration: Equatable, Sendable {
    let renderLimits: OffscreenRenderLimits
    let sessionLimits: AgentSessionLimits

    /// Creates render and agent-session policy.
    init(
        renderLimits: OffscreenRenderLimits = .conservativeDefault,
        sessionLimits: AgentSessionLimits = .conservativeDefault
    ) {
        self.renderLimits = renderLimits
        self.sessionLimits = sessionLimits
    }

    /// Constructs one closed agent assembly from consumer Game Content.
    @MainActor
    func makeAssembly(
        gameContent: BasicGameContent,
        agentSessionID: AgentSessionID = AgentSessionID(),
        simulationSessionID: SimulationSessionID = SimulationSessionID()
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
            captureTarget: offlineAssembly.captureTarget
        )

        return AgentSessionAssembly(
            sessionID: agentSessionID,
            initialCursor: offlineAssembly.initialCursor,
            offlineAssembly: offlineAssembly,
            coordinator: coordinator
        )
    }
}
