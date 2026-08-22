@testable import Engine2

/// Test-only view of the ordinary material identities published by the PBR fixture.
///
/// Construction deliberately follows the ordinary Game Content → `World` →
/// `SimulationPresentationSnapshot` → `RenderFrame` path. GPU and BRDF tests
/// consume these projected identities instead of restating the validation
/// scene's six PBR cases or depending on the App's selected planet topology.
struct PublishedMaterialValidationScene {
    let catalog: RenderAssetCatalog
    let renderFrame: RenderFrame

    /// Material identities in the exact order published by the builder.
    var materialIDs: [MaterialID] {
        renderFrame.instances.map(\.materialID)
    }

    init() {
        let gameContent = BasicGameContent()
        let world = BasicWorldBuilder().buildWorld()
        let snapshot = world.presentationSnapshot(
            at: SimulationCursor(
                sessionID: SimulationSessionID(),
                tick: .zero
            )
        )

        self.catalog = gameContent.renderAssetCatalog
        self.renderFrame = RenderFrame(projecting: snapshot)
    }

    /// Resolves every published identity through the App-supplied catalog.
    func materialDescriptions() throws -> [PBRMaterialDescription] {
        try materialIDs.map { try catalog.pbrMaterialDescription(for: $0) }
    }
}
