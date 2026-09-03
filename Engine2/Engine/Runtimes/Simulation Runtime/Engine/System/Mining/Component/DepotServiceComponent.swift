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
