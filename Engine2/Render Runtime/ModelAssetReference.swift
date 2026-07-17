//
//  ModelAssetReference.swift
//  Engine2
//
//  Created by Codex on 7/16/26.
//

/// Packaged source model that a Render Runtime can resolve privately.
///
/// This value deliberately contains no Model I/O or Metal objects. Game
/// Content can therefore describe an asset without taking ownership of the
/// backend resource created from it.
nonisolated struct ModelAssetReference: Equatable, Hashable, Sendable {
    /// `Bundle` resource names are intentionally strings because they identify
    /// open-ended packaged files rather than a closed set of engine states.
    let resourceName: String
    let format: ModelAssetFormat

    init(resourceName: String, format: ModelAssetFormat) {
        precondition(!resourceName.isEmpty, "A model resource name cannot be empty.")
        self.resourceName = resourceName
        self.format = format
    }
}
