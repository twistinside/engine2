/// Capability for entity facades backed by consumable propellant mass.
protocol Fueled: Entity {
    var fuelCapacity: Double { get }
    var remainingFuel: Double { get }
}

extension Fueled {
    var fuelCapacity: Double {
        guard let fuel = world.fuelComponents[id] else {
            fatalError("There is no fuel component for the fueled entity with ID: \(id)")
        }
        return fuel.capacity
    }

    var remainingFuel: Double {
        guard let fuel = world.fuelComponents[id] else {
            fatalError("There is no fuel component for the fueled entity with ID: \(id)")
        }
        return fuel.remaining
    }
}
