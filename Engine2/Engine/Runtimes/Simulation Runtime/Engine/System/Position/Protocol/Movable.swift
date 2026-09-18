/// Capability for positioned entity facades backed by translational motion state.
///
/// Accessors expose integrated velocity, persistent acceleration intent, and
/// the pending acceleration and impulse contributions from `MotionComponent`.
/// They are ergonomic live reads for game code and tooling, not the iteration
/// surface for movement systems.
protocol Movable: Positionable {
    var acceleration: SIMD3<Double> { get }
    var accelerationIntent: MotionComponent.AccelerationIntent { get }
    var impulse: SIMD3<Double> { get }
    var velocity: SIMD3<Double> { get }
}

extension Movable {
    var acceleration: SIMD3<Double> {
        guard let motion = world.components[MotionComponent.self][self.id] else {
            fatalError("There is no motion component for the movable entity with ID: \(self.id)")
        }
        return motion.acceleration
    }

    var accelerationIntent: MotionComponent.AccelerationIntent {
        guard let motion = world.components[MotionComponent.self][self.id] else {
            fatalError("There is no motion component for the movable entity with ID: \(self.id)")
        }
        return motion.accelerationIntent
    }

    var impulse: SIMD3<Double> {
        guard let motion = world.components[MotionComponent.self][self.id] else {
            fatalError("There is no motion component for the movable entity with ID: \(self.id)")
        }
        return motion.impulse
    }

    var velocity: SIMD3<Double> {
        guard let motion = world.components[MotionComponent.self][self.id] else {
            fatalError("There is no motion component for the movable entity with ID: \(self.id)")
        }
        return motion.velocity
    }
}
