/// Counts returned by the real model-decoding path before diagnostic wrapping.
struct RenderAssetLoadCounts: Equatable, Sendable {
    let loadedModelCount: Int
    let meshCount: Int
    let submeshCount: Int
}
