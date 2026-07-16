//
//  BasicGameContent.swift
//  Engine2
//
//  Created by Codex on 7/15/26.
//

/// Example consumer content assembled by the App composition root.
///
/// This value owns game-specific construction and asset descriptions, but it
/// has no cadence, lifecycle, decoded model, or GPU resource of its own.
struct BasicGameContent {
    let worldBuilder: any PWorldBuilder

    let renderAssetCatalog: RenderAssetCatalog

    init(worldBuilder: any PWorldBuilder = BasicWorldBuilder()) {
        self.worldBuilder = worldBuilder
        self.renderAssetCatalog = RenderAssetCatalog(
            models: [
                .ball: ModelAssetReference(
                    resourceName: "Ball",
                    format: .usdz
                )
            ]
        )
    }

    /// Drop-in content configuration for visually exercising sphere response.
    /// Use `BasicGameContent.collisionDemo` in `Engine2App.init()`.
    static var collisionDemo: BasicGameContent {
        BasicGameContent(worldBuilder: CollisionWorldBuilder())
    }
}
