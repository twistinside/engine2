import simd

/// Context-resolved command state for a player-controllable entity.
///
/// The Simulation Runtime writes these semantic values only after applying
/// authoritative selection. No physical key or button identity enters the row.
struct PlayerControlComponent: Component {
    var interactionState: PlayerInteractionState
    var translation: SIMD2<Double>

    /// A fire press assigned to this entity for the current Simulation tick.
    var isFireRequested: Bool

    init(
        translation: SIMD2<Double> = .zero,
        interactionState: PlayerInteractionState = .inactive,
        isFireRequested: Bool
    ) {
        precondition(translation.isFinite, "Player translation intent must be finite.")
        self.translation = translation
        self.interactionState = interactionState
        self.isFireRequested = isFireRequested
    }
}
