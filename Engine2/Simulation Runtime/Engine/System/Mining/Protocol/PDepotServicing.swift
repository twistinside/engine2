/// Capability for depot facades that unload ore and supply infinite fuel.
protocol PDepotServicing: PPositionable {
    var deliveredOre: Double { get }
    var depotInteractionRange: Double { get }
    var refuelingRate: Double { get }
    var unloadingRate: Double { get }
}

extension PDepotServicing {
    var deliveredOre: Double {
        guard let depot = world.depotServiceComponents[id] else {
            fatalError("There is no depot service component for the depot entity with ID: \(id)")
        }
        return depot.deliveredOre
    }

    var depotInteractionRange: Double {
        guard let depot = world.depotServiceComponents[id] else {
            fatalError("There is no depot service component for the depot entity with ID: \(id)")
        }
        return depot.interactionRange
    }

    var refuelingRate: Double {
        guard let depot = world.depotServiceComponents[id] else {
            fatalError("There is no depot service component for the depot entity with ID: \(id)")
        }
        return depot.refuelingRate
    }

    var unloadingRate: Double {
        guard let depot = world.depotServiceComponents[id] else {
            fatalError("There is no depot service component for the depot entity with ID: \(id)")
        }
        return depot.unloadingRate
    }
}
