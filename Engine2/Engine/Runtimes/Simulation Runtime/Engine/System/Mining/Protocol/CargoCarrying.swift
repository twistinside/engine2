/// Capability for entity facades carrying finite ore cargo.
protocol CargoCarrying: Entity {
    var cargoCapacity: Double { get }
    var cargoOre: Double { get }
}

extension CargoCarrying {
    var cargoCapacity: Double {
        guard let cargo = world.cargoComponents[id] else {
            fatalError("There is no cargo component for the carrying entity with ID: \(id)")
        }
        return cargo.capacity
    }

    var cargoOre: Double {
        guard let cargo = world.cargoComponents[id] else {
            fatalError("There is no cargo component for the carrying entity with ID: \(id)")
        }
        return cargo.ore
    }
}
