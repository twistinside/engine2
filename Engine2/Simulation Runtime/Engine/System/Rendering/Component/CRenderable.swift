/// Abstract presentation identity for a simulation entity.
///
/// The component names mesh and material content but contains no renderer-owned
/// description, decoded model, buffer, GPU index, or other backend resource.
struct CRenderable: PComponent {
    var meshID: MeshID
    var materialID: MaterialID
}
