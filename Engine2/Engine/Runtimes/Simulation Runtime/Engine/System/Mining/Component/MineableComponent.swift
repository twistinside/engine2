/// Transfer-rate policy for one mineable entity.
struct MineableComponent: Component {
    let miningRate: Double

    init(miningRate: Double) {
        precondition(miningRate.isFinite && miningRate > 0, "A mining rate must be finite and positive.")
        self.miningRate = miningRate
    }
}

extension MineableComponent {
    @MainActor init?(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.miningRate != nil) == (entity is Mineable),
            "InitialState.miningRate must be present exactly when the entity conforms to Mineable."
        )
        guard let miningRate = state.miningRate else {
            return nil
        }
        self.init(miningRate: miningRate)
    }
}
