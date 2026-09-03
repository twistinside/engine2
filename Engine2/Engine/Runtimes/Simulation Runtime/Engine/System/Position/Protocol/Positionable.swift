/// Capability for entity facades whose live position is stored in ECS state.
///
/// The default accessor resolves `PositionComponent` from the entity's world and treats
/// a missing row as a violated registration invariant. Systems should query the
/// component store directly when processing positions in bulk.
protocol Positionable: Entity {
    var position: SIMD3<Double> { get }
}

extension Positionable {
    var position: SIMD3<Double> {
        guard let position = world.positionComponents[self.id]?.position else {
            fatalError("There is no position for the positionable entity with ID: \(self.id)")
        }
        return position
    }
}
