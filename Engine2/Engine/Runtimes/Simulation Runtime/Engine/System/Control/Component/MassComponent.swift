/// Fixed dry mass whose live value also includes stored fuel and cargo.
struct MassComponent: Component {
    let dryMass: Double

    init(dryMass: Double) {
        precondition(dryMass.isFinite && dryMass > 0, "Dry mass must be finite and positive.")
        self.dryMass = dryMass
    }

    /// Returns dry mass plus the currently stored propellant and ore.
    func totalMass(fuel: FuelComponent?, cargo: CargoComponent?) -> Double {
        dryMass + (fuel?.remaining ?? 0) + (cargo?.ore ?? 0)
    }
}
