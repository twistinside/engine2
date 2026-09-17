/// Infinite-fuel depot policy and authoritative delivered-ore total.
struct DepotServiceComponent: Component {
    let refuelingRate: Double
    let unloadingRate: Double
    var deliveredOre: Double

    init(unloadingRate: Double, refuelingRate: Double, deliveredOre: Double = 0) {
        precondition(unloadingRate.isFinite && unloadingRate > 0, "A depot unloading rate must be finite and positive.")
        precondition(refuelingRate.isFinite && refuelingRate > 0, "A depot refueling rate must be finite and positive.")
        precondition(deliveredOre.isFinite && deliveredOre >= 0, "Delivered ore must be finite and nonnegative.")
        self.unloadingRate = unloadingRate
        self.refuelingRate = refuelingRate
        self.deliveredOre = deliveredOre
    }
}

extension DepotServiceComponent {
    @MainActor init?(for entity: Entity, from state: Entity.InitialState) {
        let isDepotServicing = entity is DepotServicing
        precondition(
            (state.depotUnloadingRate != nil) == isDepotServicing &&
                (state.depotRefuelingRate != nil) == isDepotServicing,
            "DepotServicing requires unloading and refueling rates; other entities must omit both."
        )
        guard let depotUnloadingRate = state.depotUnloadingRate,
              let depotRefuelingRate = state.depotRefuelingRate else {
            return nil
        }
        self.init(
            unloadingRate: depotUnloadingRate,
            refuelingRate: depotRefuelingRate,
            deliveredOre: 0
        )
    }
}
