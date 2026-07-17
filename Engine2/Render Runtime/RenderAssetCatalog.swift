//
//  RenderAssetCatalog.swift
//  Engine2
//
//  Created by Codex on 7/15/26.
//

/// Render-owned input contract that maps Game Content mesh identities to
/// packaged model assets.
nonisolated struct RenderAssetCatalog: Equatable, Sendable {
    let models: [MeshID: ModelAssetReference]

    init(models: [MeshID: ModelAssetReference]) {
        self.models = models
    }
}
