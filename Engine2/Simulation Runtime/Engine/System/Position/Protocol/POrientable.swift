import simd

/// Capability for entity facades whose live orientation is stored in ECS state.
///
/// The default accessor resolves `CRotation` from the entity's world. A missing
/// row indicates that capability-driven registration and the facade's declared
/// conformance have diverged.
protocol POrientable: Entity {
    var rotation: simd_quatf { get }
}

extension POrientable {
    var rotation: simd_quatf {
        guard let rotation = world.rotationComponents[self.id]?.rotation else {
            fatalError("There is no rotation for the rotatable entity with ID: \(self.id)")
        }
        return rotation
    }
}
