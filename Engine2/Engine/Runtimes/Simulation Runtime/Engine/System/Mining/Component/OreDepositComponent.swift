/// Finite mineable ore remaining in one resource body.
struct OreDepositComponent: Component {
    var remainingOre: Double

    init(remainingOre: Double) {
        precondition(remainingOre.isFinite && remainingOre >= 0, "Remaining ore must be finite and nonnegative.")
        self.remainingOre = remainingOre
    }
}

extension OreDepositComponent {
    @MainActor init?(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.remainingOre != nil) == (entity is OreContaining),
            "InitialState.remainingOre must be present exactly when the entity conforms to OreContaining."
        )
        guard let remainingOre = state.remainingOre else {
            return nil
        }
        self.init(remainingOre: remainingOre)
    }
}
