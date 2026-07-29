/// Capability for entities that advertise continuous mesh/material presentation.
public protocol PRenderable: Entity {
    /// Current backend-neutral mesh identity stored in ECS state.
    var meshID: MeshAssetKey { get }

    /// Current backend-neutral material identity stored in ECS state.
    var materialID: MaterialAssetKey { get }
}

public extension PRenderable {
    var meshID: MeshAssetKey {
        guard let renderable = world.renderableComponents[self.id] else {
            fatalError("There is no renderable component for the renderable entity with ID: \(self.id)")
        }
        return renderable.meshID
    }

    var materialID: MaterialAssetKey {
        guard let renderable = world.renderableComponents[self.id] else {
            fatalError("There is no renderable component for the renderable entity with ID: \(self.id)")
        }
        return renderable.materialID
    }
}
