/// Capability for entity facades whose lifetime is advanced by the Simulation.
protocol Expirable: Entity {
    var remainingLifetime: Double { get }
}

extension Expirable {
    var remainingLifetime: Double {
        guard let lifetime = world.lifetimeComponents[id] else {
            fatalError("There is no lifetime component for the expirable entity with ID: \(id)")
        }
        return lifetime.remainingLifetime
    }
}
