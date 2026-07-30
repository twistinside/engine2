import SwiftUI

/// Owns one idempotent agent session without exposing lower-level capabilities.
///
/// The retained offline assembly keeps Simulation, Metal, and capture workflow
/// ownership alive. Callers receive only immutable starting identity, the agent
/// capability, coordinated drain-before-close lifecycle, and an identity view that
/// adds no transport or lower-level authority.
struct AgentSessionAssembly: PRuntimeAssembly {
    nonisolated let sessionID: AgentSessionID
    nonisolated let initialCursor: SimulationCursor
    nonisolated let firstRequestID: AgentSessionRequestID

    private let offlineAssembly: OfflineCaptureAssembly
    private let coordinator: AgentSessionCoordinator

    /// Root identity UI for this transport-neutral live session.
    var body: some View {
        AgentSessionAssemblyView(assembly: self)
    }

    /// Sole request capability exposed to an App or future transport adapter.
    nonisolated var target: any PAgentSessionTarget {
        coordinator
    }

    /// Constructs an agent graph with conservative Render, work, and retention
    /// limits plus fresh agent and Simulation session identities.
    init(gameContent: any PGameContent) throws {
        try self.init(
            gameContent: gameContent,
            renderLimits: .conservative,
            sessionLimits: .conservative,
            agentSessionID: AgentSessionID(),
            simulationSessionID: SimulationSessionID()
        )
    }

    /// Constructs an agent graph from explicit content, policy, and identities.
    init(
        gameContent: any PGameContent,
        renderLimits: OffscreenRenderLimits,
        sessionLimits: AgentSessionLimits,
        agentSessionID: AgentSessionID,
        simulationSessionID: SimulationSessionID
    ) throws {
        let offlineAssembly = try OfflineCaptureAssembly(
            gameContent: gameContent,
            renderLimits: renderLimits,
            sessionID: simulationSessionID
        )
        let coordinator = AgentSessionCoordinator(
            sessionID: agentSessionID,
            initialCursor: offlineAssembly.initialCursor,
            limits: sessionLimits,
            captureTarget: offlineAssembly.captureTarget,
            initialRequestSequence: .first
        )

        self.sessionID = agentSessionID
        self.initialCursor = offlineAssembly.initialCursor
        self.firstRequestID = AgentSessionRequestID(
            sessionID: agentSessionID,
            sequence: .first
        )
        self.offlineAssembly = offlineAssembly
        self.coordinator = coordinator
    }

    /// Refuses new unique work immediately and awaits accepted work completion.
    nonisolated func stopAndDrain() async {
        await coordinator.stopAndDrain()
    }
}
