/// Immutable recipe for one serial render-gated offline capture topology.
///
/// Unlike a generic mode bag, this configuration always constructs exactly one
/// authoritative Simulation Runtime, one dedicated offscreen Metal Runtime,
/// and one coordinator that alone receives their directed capabilities. There
/// is no Input Runtime, wall-clock cadence, screen surface, or optional peer.
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
        let simulationRuntime = SimulationRuntime(
            worldBuilder: gameContent.worldBuilder,
            configuration: gameContent.simulationConfiguration,
            inputBaseline: nil,
            sessionID: sessionID
        )
        let renderRuntime = try MetalOffscreenRenderRuntime(
            catalog: gameContent.renderAssetCatalog,
            limits: renderLimits
        )
        let initialPresentationSnapshot =
            simulationRuntime.latestPresentationSnapshot
        let coordinator = OfflineCaptureCoordinator(
            advanceTarget: simulationRuntime,
            initialPresentationSnapshot: initialPresentationSnapshot,
            renderTarget: renderRuntime,
            artifactEncoder: try ImageIOArtifactEncoder()
        )

        // Only immutable initial identity and the coordinator's narrow workflow
        // leave composition. The Runtime references remain coordinator-owned.
        return OfflineCaptureAssembly(
            initialCursor: initialPresentationSnapshot.cursor,
            coordinator: coordinator
        )
    }
}
