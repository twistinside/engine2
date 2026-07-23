/// Immutable recipe for one serial render-gated offline capture topology.
///
/// Unlike a generic mode bag, this configuration always constructs exactly one
/// authoritative Simulation Runtime, one dedicated offscreen Metal Runtime,
/// and one coordinator that alone receives their directed capabilities. There
/// is no Input Runtime, wall-clock cadence, screen surface, or optional peer.
nonisolated struct OfflineCaptureConfiguration: Equatable, Sendable {
    let fixedTimeStep: Duration
    let renderLimits: OffscreenRenderLimits

    /// Creates offline Simulation timing and allocation/readback policy.
    init(
        fixedTimeStep: Duration = .seconds(1.0 / 60.0),
        renderLimits: OffscreenRenderLimits = .conservativeDefault
    ) {
        precondition(
            fixedTimeStep > .zero,
            "Offline Simulation requires a positive fixed time step."
        )
        self.fixedTimeStep = fixedTimeStep
        self.renderLimits = renderLimits
    }

    /// Constructs one isolated production assembly from consumer Game Content.
    @MainActor
    func makeAssembly(
        gameContent: BasicGameContent,
        sessionID: SimulationSessionID = SimulationSessionID()
    ) throws -> OfflineCaptureAssembly {
        let simulationRuntime = SimulationRuntime(
            worldBuilder: gameContent.worldBuilder,
            sessionID: sessionID,
            fixedTimeStep: fixedTimeStep
        )
        let renderRuntime = try MetalOffscreenRenderRuntime(
            catalog: gameContent.renderAssetCatalog,
            limits: renderLimits
        )
        let coordinator = OfflineCaptureCoordinator(
            advanceTarget: simulationRuntime,
            renderTarget: renderRuntime
        )

        // Only immutable initial identity and the coordinator's narrow workflow
        // leave composition. The Runtime references remain coordinator-owned.
        return OfflineCaptureAssembly(
            initialCursor: simulationRuntime.currentCursor,
            coordinator: coordinator
        )
    }
}
