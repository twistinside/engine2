import Engine2

/// Exhaustive Game Content identity for authored surface materials.
///
/// The identity never exposes material factors, GPU storage, or Metal
/// resources. Runtime boundaries carry its explicit `assetKey` projection,
/// while `CaseIterable` supplies the exhaustive validation order.
nonisolated public enum MaterialID: UInt32, CaseIterable, Codable, Hashable, Sendable {
    case warmDielectricSmooth = 0
    case warmDielectric = 1
    case warmDielectricRough = 2
    case goldMetalSmooth = 3
    case goldMetal = 4
    case goldMetalRough = 5

    public var assetKey: MaterialAssetKey {
        MaterialAssetKey(rawValue: rawValue)
    }
}
