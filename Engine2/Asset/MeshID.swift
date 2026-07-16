//
//  MeshID.swift
//  Engine2
//
//  Created by Codex on 7/15/26.
//

/// Backend-neutral identity for mesh content referenced by gameplay state.
///
/// Game Content defines the meaningful IDs while each Render Runtime resolves
/// those IDs into its own backend-specific resources.
struct MeshID: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        precondition(!rawValue.isEmpty, "A mesh ID cannot be empty.")
        self.rawValue = rawValue
    }
}
