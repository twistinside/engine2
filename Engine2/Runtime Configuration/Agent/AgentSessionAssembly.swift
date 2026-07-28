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

    /// Constructs the production agent graph from Basic Game Content and
    /// conservative Render, work, and retention limits.
    init() throws {
        try self.init(
            gameContent: BasicGameContent(),
            configuration: AgentSessionConfiguration(
                renderLimits: .conservative,
                sessionLimits: .conservative
            ),
            agentSessionID: AgentSessionID(),
            simulationSessionID: SimulationSessionID()
        )
    }

    /// Constructs an agent graph from explicit content, policy, and identities.
    init(
        gameContent: BasicGameContent,
        configuration: AgentSessionConfiguration,
        agentSessionID: AgentSessionID,
        simulationSessionID: SimulationSessionID
    ) throws {
        let offlineAssembly = try OfflineCaptureAssembly(
            gameContent: gameContent,
            configuration: OfflineCaptureConfiguration(
                renderLimits: configuration.renderLimits
            ),
            sessionID: simulationSessionID
        )
        let coordinator = AgentSessionCoordinator(
            sessionID: agentSessionID,
            initialCursor: offlineAssembly.initialCursor,
            limits: configuration.sessionLimits,
            captureTarget: offlineAssembly.captureTarget,
            initialRequestSequence: .first
        )

        self.init(
            sessionID: agentSessionID,
            initialCursor: offlineAssembly.initialCursor,
            offlineAssembly: offlineAssembly,
            coordinator: coordinator
        )
    }

    init(
        sessionID: AgentSessionID,
        initialCursor: SimulationCursor,
        offlineAssembly: OfflineCaptureAssembly,
        coordinator: AgentSessionCoordinator
    ) {
        self.sessionID = sessionID
        self.initialCursor = initialCursor
        self.firstRequestID = AgentSessionRequestID(
            sessionID: sessionID,
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
