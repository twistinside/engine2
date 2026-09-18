/// Consumable propellant mass for one entity.
struct FuelComponent: Component {
    let capacity: Double
    var remaining: Double

    init(capacity: Double, remaining: Double) {
        precondition(capacity.isFinite && capacity > 0, "Fuel capacity must be finite and positive.")
        precondition(remaining.isFinite && remaining >= 0 && remaining <= capacity, "Remaining fuel must be within capacity.")
        self.capacity = capacity
        self.remaining = remaining
    }
}

extension FuelComponent {
    @MainActor init?(for entity: Entity, from state: Entity.InitialState) {
        let isFueled = entity is Fueled
        precondition(
            (state.fuelCapacity != nil) == isFueled &&
                (state.fuelRemaining != nil) == isFueled,
            "Fueled requires fuel capacity and remaining fuel; other entities must omit both."
        )
        guard let fuelCapacity = state.fuelCapacity, let fuelRemaining = state.fuelRemaining else {
            return nil
        }
        self.init(capacity: fuelCapacity, remaining: fuelRemaining)
    }
}
