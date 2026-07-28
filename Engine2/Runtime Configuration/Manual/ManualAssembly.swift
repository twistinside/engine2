import SwiftUI

/// Owns one caller-driven Simulation Runtime without an automatic cadence.
///
/// The assembly deliberately exposes the Runtime's narrow advance and
/// presentation capabilities plus its root view while retaining the concrete
/// Runtime for topology-specific tooling. With no driver in this topology,
/// silence means no progress.
struct ManualAssembly: PRuntimeAssembly {
    let simulationRuntime: SimulationRuntime
    let renderAssetCatalog: RenderAssetCatalog

    /// Root UI for exact caller-driven advancement and screen presentation.
    var body: some View {
        ManualAssemblyView(assembly: self)
    }

    /// Narrow capability used by callers that may live outside MainActor.
    nonisolated var advanceTarget: any PSimulationAdvanceTarget {
        simulationRuntime
    }

    /// Latest-value presentation capability for independently paced consumers.
    var presentationSource: any PSimulationPresentationSource {
        simulationRuntime
    }

    /// Constructs the production manual graph from Basic Game Content.
    init() {
        self.init(
            gameContent: BasicGameContent(),
            sessionID: SimulationSessionID()
        )
    }

    /// Constructs a manual graph from explicit content and session identity.
    init(
        gameContent: BasicGameContent,
        sessionID: SimulationSessionID
    ) {
        let simulationRuntime = SimulationRuntime(
            worldBuilder: gameContent.worldBuilder,
            configuration: gameContent.simulationConfiguration,
            inputBaseline: nil,
            sessionID: sessionID
        )
        self.init(
            simulationRuntime: simulationRuntime,
            renderAssetCatalog: gameContent.renderAssetCatalog
        )
    }

    init(
        simulationRuntime: SimulationRuntime,
        renderAssetCatalog: RenderAssetCatalog
    ) {
        self.simulationRuntime = simulationRuntime
        self.renderAssetCatalog = renderAssetCatalog
    }
}
