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

    /// Constructs a manual graph with a fresh Simulation session identity.
    init(gameContent: any PGameContent) {
        self.init(
            gameContent: gameContent,
            sessionID: SimulationSessionID()
        )
    }

    /// Constructs a manual graph from explicit content and session identity.
    init(
        gameContent: any PGameContent,
        sessionID: SimulationSessionID
    ) {
        let simulationRuntime = SimulationRuntime(
            worldBuilder: gameContent.worldBuilder,
            configuration: gameContent.simulationConfiguration,
            inputBaseline: nil,
            sessionID: sessionID
        )
        self.simulationRuntime = simulationRuntime
        self.renderAssetCatalog = gameContent.renderAssetCatalog
    }
}
