@testable import Engine2

/// Test-only view of the material identities published by the example app.
///
/// Construction deliberately follows the ordinary Game Content → `World` →
/// `SimulationPresentationSnapshot` → `RenderFrame` path. GPU and BRDF tests
/// consume these projected identities instead of restating the validation
/// scene's six material cases or depending on `MaterialID.allCases` ordering.
@MainActor
struct PublishedMaterialValidationScene {
    let catalog: RenderAssetCatalog
    let renderFrame: RenderFrame

    init() {
        let gameContent = BasicGameContent()
        let world = gameContent.worldBuilder.buildWorld()
        let snapshot = SimulationPresentationSnapshot.capture(
            from: world,
            at: .zero
        )

        self.catalog = gameContent.renderAssetCatalog
        self.renderFrame = RenderFrame.project(from: snapshot)
    }

    /// Material identities in the exact order published by the builder.
    var materialIDs: [MaterialID] {
        renderFrame.instances.map(\.materialID)
    }

    /// Resolves every published identity through the App-supplied catalog.
    func materialDescriptions() throws -> [PBRMaterialDescription] {
        try materialIDs.map { try catalog.materialDescription(for: $0) }
    }
}
