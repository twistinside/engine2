/// Proximity and transfer-rate policy for one mineable entity.
struct CMineable: PComponent {
    let interactionRange: Double
    let miningRate: Double

    init(interactionRange: Double, miningRate: Double) {
        precondition(interactionRange.isFinite && interactionRange > 0, "A mining interaction range must be finite and positive.")
        precondition(miningRate.isFinite && miningRate > 0, "A mining rate must be finite and positive.")
        self.interactionRange = interactionRange
        self.miningRate = miningRate
    }
}
