/// Capability for entities that advertise continuous mesh/material presentation.
protocol PRenderable: Entity {
    /// Mesh used when the entity is first registered with its world.
    var initialMeshID: MeshID { get }

    /// Material used when the entity is first registered with its world.
    var initialMaterialID: MaterialID { get }

    /// Current backend-neutral mesh identity stored in ECS state.
    var meshID: MeshID { get }

    /// Current backend-neutral material identity stored in ECS state.
    var materialID: MaterialID { get }
}

extension PRenderable {
    var meshID: MeshID {
        guard let renderable = world.renderableComponents[self.id] else {
            fatalError("There is no renderable component for the renderable entity with ID: \(self.id)")
        }
        return renderable.meshID
    }

    var materialID: MaterialID {
        guard let renderable = world.renderableComponents[self.id] else {
            fatalError("There is no renderable component for the renderable entity with ID: \(self.id)")
        }
        return renderable.materialID
    }
}
