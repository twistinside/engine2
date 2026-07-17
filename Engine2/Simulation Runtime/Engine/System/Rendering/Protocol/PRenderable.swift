//
//  PRenderable.swift
//  Engine2
//
//  Created by Codex on 7/15/26.
//

/// Capability for entities that advertise continuous mesh presentation.
protocol PRenderable: Entity {
    /// Mesh used when the entity is first registered with its world.
    var initialMeshID: MeshID { get }

    /// Current backend-neutral mesh identity stored in ECS state.
    var meshID: MeshID { get }
}

extension PRenderable {
    var meshID: MeshID {
        guard let renderable = world.renderableComponents[self.id] else {
            fatalError("There is no renderable component for the renderable entity with ID: \(self.id)")
        }
        return renderable.meshID
    }
}
