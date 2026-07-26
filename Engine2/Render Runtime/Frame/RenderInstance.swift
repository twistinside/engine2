/// Render-owned projection of one entity's abstract presentation state.
///
/// Mesh and material identities remain backend-neutral here. Later Render
/// stages privately resolve them without exposing descriptions or GPU resources
/// to the Simulation-owned source snapshot.
struct RenderInstance: Equatable {
    /// Missing-scale projection policy for renderable entities without scale state.
    static let defaultScale = SIMD3<Float>(repeating: 0.5)

    let meshID: MeshID
    let materialID: MaterialID
    let transform: Transform
}
