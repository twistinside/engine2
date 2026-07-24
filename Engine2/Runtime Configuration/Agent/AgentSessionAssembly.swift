/// Owns one idempotent agent session without exposing lower-level capabilities.
///
/// The retained offline assembly keeps Simulation, Metal, and capture workflow
/// ownership alive. Callers receive only immutable starting identity, the agent
/// capability, and coordinated drain-before-close lifecycle.
@MainActor
final class AgentSessionAssembly {
    nonisolated let sessionID: AgentSessionID
    nonisolated let initialCursor: SimulationCursor
    nonisolated let firstRequestID: AgentSessionRequestID

    private let offlineAssembly: OfflineCaptureAssembly
    private let coordinator: AgentSessionCoordinator

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

    /// Sole request capability exposed to an App or future transport adapter.
    nonisolated var target: any PAgentSessionTarget {
        coordinator
    }

    /// Refuses new unique work immediately and awaits accepted work completion.
    nonisolated func stopAndDrain() async {
        await coordinator.stopAndDrain()
    }
}
