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
