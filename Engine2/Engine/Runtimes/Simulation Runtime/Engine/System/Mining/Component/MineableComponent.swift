/// Transfer-rate policy for one mineable entity.
struct MineableComponent: Component {
    let miningRate: Double

    init(miningRate: Double) {
        precondition(miningRate.isFinite && miningRate > 0, "A mining rate must be finite and positive.")
        self.miningRate = miningRate
    }
}
