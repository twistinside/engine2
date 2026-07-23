/// Immutable recipe for a live-process idempotent agent capture topology.
///
/// This is deliberately not an MCP Runtime. It supplies the session semantics
/// a future authenticated transport needs while leaving transport, request DTOs,
/// structured inspection, semantic controls, and durable replay as future work.
nonisolated struct AgentSessionConfiguration: Equatable, Sendable {
    let fixedTimeStep: Duration
    let renderLimits: OffscreenRenderLimits
    let sessionLimits: AgentSessionLimits

    /// Creates Simulation, render, and agent-session policy.
    init(
        fixedTimeStep: Duration = .seconds(1.0 / 60.0),
        renderLimits: OffscreenRenderLimits = .conservativeDefault,
        sessionLimits: AgentSessionLimits = .conservativeDefault
    ) {
        precondition(
            fixedTimeStep > .zero,
            "Agent Simulation requires a positive fixed time step."
        )
        self.fixedTimeStep = fixedTimeStep
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
            fixedTimeStep: fixedTimeStep,
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
