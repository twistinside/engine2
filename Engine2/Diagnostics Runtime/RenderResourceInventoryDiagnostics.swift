/// Low-frequency structural inventory for one completed Render resource store.
struct RenderResourceInventoryDiagnostics: Codable, Equatable, Sendable {
    let modelCount: Int
    let meshCount: Int
    let submeshCount: Int
    let pipelineCount: Int
    let argumentTableCount: Int
    let materialCount: Int
    let frameResourceCount: Int
}
