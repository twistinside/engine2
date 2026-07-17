/// Capability for entity facades whose live position is stored in ECS state.
///
/// The default accessor resolves `CPosition` from the entity's world and treats
/// a missing row as a violated registration invariant. Systems should query the
/// component store directly when processing positions in bulk.
protocol PPositionable: Entity {
    var position: SIMD3<Float> { get }
}

extension PPositionable {
    var position: SIMD3<Float> {
        guard let position = world.positionComponents[self.id]?.position else {
            fatalError("There is no position for the positionable entity with ID: \(self.id)")
        }
        return position
    }
}
