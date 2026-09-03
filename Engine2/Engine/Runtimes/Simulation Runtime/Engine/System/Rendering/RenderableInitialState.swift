/// Paired mesh and material values used to register a renderable entity.
///
/// Game Content supplies this focused spawn-time value to `World.add` while
/// `Renderable` remains a live capability over the resulting ECS component.
/// Keeping both identities together prevents a partially specified
/// `RenderableComponent` row.
struct RenderableInitialState {
    let meshID: MeshID
    let materialID: MaterialID
}
