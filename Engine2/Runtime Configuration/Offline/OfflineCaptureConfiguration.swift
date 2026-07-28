/// Immutable recipe for one serial render-gated offline capture topology.
///
/// The value carries explicit Render limits for injected construction.
/// ``OfflineCaptureAssembly`` owns the graph construction: exactly one
/// authoritative Simulation Runtime, one dedicated offscreen Metal Runtime,
/// and one coordinator that alone receives their directed capabilities.
nonisolated struct OfflineCaptureConfiguration: Equatable, Sendable {
    let renderLimits: OffscreenRenderLimits

    /// Constructs one isolated production assembly with a fresh Simulation
    /// session identity.
    @MainActor
    func makeAssembly(gameContent: BasicGameContent) throws -> OfflineCaptureAssembly {
        try makeAssembly(
            gameContent: gameContent,
            sessionID: SimulationSessionID()
        )
    }

    /// Constructs one isolated production assembly with a caller-supplied
    /// Simulation identity for restoration or external correlation.
    @MainActor
    func makeAssembly(gameContent: BasicGameContent, sessionID: SimulationSessionID) throws -> OfflineCaptureAssembly {
        try OfflineCaptureAssembly(
            gameContent: gameContent,
            configuration: self,
            sessionID: sessionID
        )
    }
}
