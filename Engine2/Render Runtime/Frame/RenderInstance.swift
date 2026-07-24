import simd

/// Render-owned projection of one entity's abstract presentation state.
///
/// Mesh and material identities remain backend-neutral here. Later Render
/// stages privately resolve them without exposing descriptions or GPU resources
/// to the Simulation-owned source snapshot.
struct RenderInstance: Equatable {
    /// Default world-space size for renderable entities that do not advertise scale yet.
    static let defaultScale = SIMD3<Float>(repeating: 0.5)

    let meshID: MeshID
    let materialID: MaterialID
    let transform: Transform

    init(
        meshID: MeshID,
        materialID: MaterialID,
        transform: Transform
    ) {
        self.meshID = meshID
        self.materialID = materialID
        self.transform = transform
    }

    init(
        meshID: MeshID,
        materialID: MaterialID,
        worldPosition: SIMD3<Float>,
        rotation: simd_quatf = Transform.identityRotation,
        scale: SIMD3<Float> = defaultScale
    ) {
        self.meshID = meshID
        self.materialID = materialID
        self.transform = Transform(
            position: worldPosition,
            rotation: rotation,
            scale: scale
        )
    }
}
