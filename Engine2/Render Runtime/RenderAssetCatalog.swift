//
//  RenderAssetCatalog.swift
//  Engine2
//
//  Created by Codex on 7/15/26.
//

/// Packaged source model that a Render Runtime can resolve privately.
///
/// This value deliberately contains no Model I/O or Metal objects. Game
/// Content can therefore describe an asset without taking ownership of the
/// backend resource created from it.
struct ModelAssetReference: Equatable, Hashable, Sendable {
    enum Format: String, Equatable, Hashable, Sendable {
        case usdz
    }

    let resourceName: String
    let format: Format

    init(resourceName: String, format: Format) {
        precondition(!resourceName.isEmpty, "A model resource name cannot be empty.")
        self.resourceName = resourceName
        self.format = format
    }
}

/// Render-owned input contract that maps abstract mesh identities to packaged
/// Game Content assets.
struct RenderAssetCatalog: Equatable, Sendable {
    let models: [MeshID: ModelAssetReference]

    init(models: [MeshID: ModelAssetReference]) {
        self.models = models
    }
}
