/// Paired mesh and material values used to register a renderable entity.
///
/// Game Content supplies this focused spawn-time value to `World.add` while
/// `PRenderable` remains a live capability over the resulting ECS component.
/// Keeping both identities together prevents a partially specified
/// `CRenderable` row.
public struct RenderableInitialState {
    public let meshID: MeshAssetKey
    public let materialID: MaterialAssetKey

    public init(
        meshID: MeshAssetKey,
        materialID: MaterialAssetKey
    ) {
        self.meshID = meshID
        self.materialID = materialID
    }
}
