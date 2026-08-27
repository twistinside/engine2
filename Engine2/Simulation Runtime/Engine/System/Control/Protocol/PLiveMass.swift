/// Capability for entity facades whose mass includes current stored resources.
protocol PLiveMass: Entity {
    var dryMass: Double { get }
    var mass: Double { get }
}

extension PLiveMass {
    var dryMass: Double {
        guard let mass = world.massComponents[id] else {
            fatalError("There is no mass component for the massive entity with ID: \(id)")
        }
        return mass.dryMass
    }

    var mass: Double {
        guard let mass = world.liveMass(for: id) else {
            fatalError("There is no live mass for the massive entity with ID: \(id)")
        }
        return mass
    }
}
