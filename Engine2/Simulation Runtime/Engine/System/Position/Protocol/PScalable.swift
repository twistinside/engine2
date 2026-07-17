/// Capability for entity facades whose live scale is stored in ECS state.
///
/// The default accessor expects capability-driven registration to have created
/// a `CScale` row and reports a missing row as a programming invariant failure.
protocol PScalable: Entity {
    var scale: SIMD3<Float> { get }
}

extension PScalable {
    var scale: SIMD3<Float> {
        guard let scale = world.scaleComponents[self.id]?.scale else {
            fatalError("There is no scale for the scalable entity with ID: \(self.id)")
        }
        return scale
    }
}
