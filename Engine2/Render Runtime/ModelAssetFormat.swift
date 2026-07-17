//
//  ModelAssetFormat.swift
//  Engine2
//
//  Created by Codex on 7/16/26.
//

/// Packaged model formats supported by the current Render Runtime.
///
/// The raw string is deliberate because `Bundle` accepts a filename extension
/// string when resolving the packaged model.
nonisolated enum ModelAssetFormat: String, Equatable, Hashable, Sendable {
    case usdz
}
