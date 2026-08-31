/// Capability for entity facades with a finite mineable ore deposit.
protocol POreContaining: Entity {
    var remainingOre: Double { get }
}

extension POreContaining {
    var remainingOre: Double {
        guard let deposit = world.oreDepositComponents[id] else {
            fatalError("There is no ore deposit for the resource entity with ID: \(id)")
        }
        return deposit.remainingOre
    }
}
