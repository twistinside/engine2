/// Backend model construction counts collected outside the frame path.
struct AssetLoadDiagnostics: Codable, Equatable, Sendable {
    let requestedModelCount: Int
    let loadedModelCount: Int
    let meshCount: Int
    let submeshCount: Int
    let succeeded: Bool
    let durationNanoseconds: UInt64
}
