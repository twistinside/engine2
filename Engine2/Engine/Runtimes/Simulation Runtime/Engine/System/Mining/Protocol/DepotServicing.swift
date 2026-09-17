/// Capability for depot facades that unload ore and supply infinite fuel.
protocol DepotServicing: Interactable {
    var deliveredOre: Double { get }
    var refuelingRate: Double { get }
    var unloadingRate: Double { get }
}

extension DepotServicing {
    var deliveredOre: Double {
        guard let depot = world.components[DepotServiceComponent.self][id] else {
            fatalError("There is no depot service component for the depot entity with ID: \(id)")
        }
        return depot.deliveredOre
    }

    var refuelingRate: Double {
        guard let depot = world.components[DepotServiceComponent.self][id] else {
            fatalError("There is no depot service component for the depot entity with ID: \(id)")
        }
        return depot.refuelingRate
    }

    var unloadingRate: Double {
        guard let depot = world.components[DepotServiceComponent.self][id] else {
            fatalError("There is no depot service component for the depot entity with ID: \(id)")
        }
        return depot.unloadingRate
    }
}
