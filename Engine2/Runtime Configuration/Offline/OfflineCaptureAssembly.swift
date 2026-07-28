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

    /// Constructs the production offline graph from Basic Game Content and
    /// conservative Render limits.
    init() throws {
        try self.init(
            gameContent: BasicGameContent(),
            configuration: OfflineCaptureConfiguration(
                renderLimits: .conservative
            ),
            sessionID: SimulationSessionID()
        )
    }

    /// Constructs an offline graph from explicit content, policy, and identity.
    init(
        gameContent: BasicGameContent,
        configuration: OfflineCaptureConfiguration,
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
            limits: configuration.renderLimits
        )
        let initialPresentationSnapshot =
            simulationRuntime.latestPresentationSnapshot
        let coordinator = OfflineCaptureCoordinator(
            advanceTarget: simulationRuntime,
            initialPresentationSnapshot: initialPresentationSnapshot,
            renderTarget: renderRuntime,
            artifactEncoder: try ImageIOArtifactEncoder()
        )

        self.init(
            initialCursor: initialPresentationSnapshot.cursor,
            coordinator: coordinator
        )
    }

    init(initialCursor: SimulationCursor, coordinator: OfflineCaptureCoordinator) {
        self.initialCursor = initialCursor
        self.coordinator = coordinator
    }
}
