/// Finite ore storage carried by one entity.
struct CargoComponent: Component {
    let capacity: Double
    var ore: Double

    init(capacity: Double, ore: Double = 0) {
        precondition(capacity.isFinite && capacity > 0, "Cargo capacity must be finite and positive.")
        precondition(ore.isFinite && ore >= 0 && ore <= capacity, "Cargo ore must be within capacity.")
        self.capacity = capacity
        self.ore = ore
    }
}

extension CargoComponent {
    @MainActor init?(for entity: Entity, from state: Entity.InitialState) {
        let isCargoCarrying = entity is CargoCarrying
        precondition(
            (state.cargoCapacity != nil) == isCargoCarrying &&
                (state.cargoOre != nil) == isCargoCarrying,
            "CargoCarrying requires cargo capacity and ore; other entities must omit both."
        )
        guard let cargoCapacity = state.cargoCapacity, let cargoOre = state.cargoOre else {
            return nil
        }
        self.init(capacity: cargoCapacity, ore: cargoOre)
    }
}
