/// An entity facade exposing the current health that Simulation systems may reduce through damage.
///
/// This capability adds damage susceptibility to Entity's universal deferred-removal capability.
/// It does not select the entity as a weapon target or require a collision body.
protocol Damageable: Entity {
    var health: HitPoints { get }
}

extension Damageable {
    var health: HitPoints {
        guard let component = world.healthComponents[id] else {
            fatalError("There is no health component for the damageable entity with ID: \(id)")
        }
        return component.health
    }
}
