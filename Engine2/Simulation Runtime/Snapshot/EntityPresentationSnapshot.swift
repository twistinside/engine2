//
//  EntityPresentationSnapshot.swift
//  Engine2
//
//  Created by Codex on 7/16/26.
//

import simd

/// Immutable presentation facts for one presented entity at a completed tick.
///
/// This first boundary exposes identity, spatial state, and abstract
/// presentation identity without exposing component rows or entity facades.
struct EntityPresentationSnapshot {
    let id: EntityID
    let position: SIMD3<Float>?
    let rotation: simd_quatf?
    let scale: SIMD3<Float>?
    let meshID: MeshID
}

extension EntityPresentationSnapshot: Equatable {
    static func == (
        lhs: EntityPresentationSnapshot,
        rhs: EntityPresentationSnapshot
    ) -> Bool {
        lhs.id == rhs.id &&
        lhs.position == rhs.position &&
        lhs.rotation?.vector == rhs.rotation?.vector &&
        lhs.scale == rhs.scale &&
        lhs.meshID == rhs.meshID
    }
}
