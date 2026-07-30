import SwiftUI

/// Owns one render-gated offline capture topology without exposing its peers.
///
/// Clients receive the initial exact cursor, one narrow capture capability, and
/// a static identity view. The concrete Simulation Runtime, offscreen Render
/// Runtime, and coordinator remain retained behind that boundary, so no second
/// caller can bypass serial capture policy and become an accidental advance
/// authority.
struct OfflineCaptureAssembly: PRuntimeAssembly {
    /// Cursor from which the first optimistic capture request may advance.
    let initialCursor: SimulationCursor

    private let coordinator: OfflineCaptureCoordinator

    /// Root identity UI for this exact request-driven topology.
    var body: some View {
        OfflineCaptureAssemblyView(assembly: self)
    }

    /// Sole directed workflow capability exposed by this assembly.
    nonisolated var captureTarget: any POfflineCaptureTarget {
        coordinator
    }

    /// Constructs an offline graph with conservative Render limits and a fresh
    /// Simulation session identity.
    init(gameContent: any PGameContent) throws {
        try self.init(
            gameContent: gameContent,
            renderLimits: .conservative,
            sessionID: SimulationSessionID()
        )
    }

    /// Constructs an offline graph from explicit content, policy, and identity.
    init(
        gameContent: any PGameContent,
        renderLimits: OffscreenRenderLimits,
        sessionID: SimulationSessionID
    ) throws {
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

        self.initialCursor = initialPresentationSnapshot.cursor
        self.coordinator = coordinator
    }
}
