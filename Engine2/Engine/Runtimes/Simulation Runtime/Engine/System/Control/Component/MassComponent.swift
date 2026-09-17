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

extension MassComponent {
    @MainActor init?(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.dryMass != nil) == (entity is LiveMass),
            "InitialState.dryMass must be present exactly when the entity conforms to LiveMass."
        )
        guard let dryMass = state.dryMass else {
            return nil
        }
        self.init(dryMass: dryMass)
    }
}
