/// Finite ore storage carried by one entity.
struct CCargo: PComponent {
    let capacity: Double
    var ore: Double

    init(capacity: Double, ore: Double = 0) {
        precondition(capacity.isFinite && capacity > 0, "Cargo capacity must be finite and positive.")
        precondition(ore.isFinite && ore >= 0 && ore <= capacity, "Cargo ore must be within capacity.")
        self.capacity = capacity
        self.ore = ore
    }
}
