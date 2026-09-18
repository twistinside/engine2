/// Abstract presentation identity for a simulation entity.
///
/// The component names mesh and material content but contains no renderer-owned
/// description, decoded model, buffer, GPU index, or other backend resource.
struct RenderableComponent: Component {
    var meshID: MeshID
    var materialID: MaterialID
}

extension RenderableComponent {
    @MainActor init?(for entity: Entity, from state: Entity.InitialState) {
        let isRenderable = entity is Renderable
        precondition(
            (state.meshID != nil) == isRenderable &&
                (state.materialID != nil) == isRenderable,
            "Renderable requires mesh and material identities; other entities must omit both."
        )
        guard let meshID = state.meshID, let materialID = state.materialID else {
            return nil
        }
        self.init(meshID: meshID, materialID: materialID)
    }
}
