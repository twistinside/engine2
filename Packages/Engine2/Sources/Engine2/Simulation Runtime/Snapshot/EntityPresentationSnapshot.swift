import simd

/// Immutable presentation facts for one presented entity at a completed tick.
///
/// This first boundary exposes identity, spatial state, and abstract
/// presentation identity without exposing component rows or entity facades.
public nonisolated struct EntityPresentationSnapshot: Sendable {
    public let id: EntityID
    public let position: SIMD3<Float>?
    public let rotation: simd_quatf?
    public let scale: SIMD3<Float>?
    public let meshID: MeshAssetKey
    public let materialID: MaterialAssetKey
}

extension EntityPresentationSnapshot: Equatable {
    public static func == (
        lhs: EntityPresentationSnapshot,
        rhs: EntityPresentationSnapshot
    ) -> Bool {
        lhs.id == rhs.id &&
        lhs.position == rhs.position &&
        lhs.rotation?.vector == rhs.rotation?.vector &&
        lhs.scale == rhs.scale &&
        lhs.meshID == rhs.meshID &&
        lhs.materialID == rhs.materialID
    }
}
