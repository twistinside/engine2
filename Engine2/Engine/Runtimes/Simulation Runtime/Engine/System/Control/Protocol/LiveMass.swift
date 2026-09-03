/// Capability for entity facades whose mass includes current stored resources.
protocol LiveMass: Entity {
    var dryMass: Double { get }
    var mass: Double { get }
}

extension LiveMass {
    var dryMass: Double {
        guard let mass = world.massComponents[id] else {
            fatalError("There is no mass component for the massive entity with ID: \(id)")
        }
        return mass.dryMass
    }

    var mass: Double {
        guard let mass = world.massComponents[id] else {
            fatalError("There is no live mass for the massive entity with ID: \(id)")
        }
        return mass.totalMass(
            fuel: world.fuelComponents[id],
            cargo: world.cargoComponents[id]
        )
    }
}
