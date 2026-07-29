import Engine2

/// Exhaustive Game Content identity for packaged mesh assets.
///
/// Game Content owns this closed vocabulary because it defines the entities and
/// meshes in this game. Runtime boundaries carry its explicit `assetKey`
/// projection so the reusable engine package does not depend on this package.
nonisolated public enum MeshID: UInt32, CaseIterable, Codable, Hashable, Sendable {
    case ball = 0

    public var assetKey: MeshAssetKey {
        MeshAssetKey(rawValue: rawValue)
    }
}
