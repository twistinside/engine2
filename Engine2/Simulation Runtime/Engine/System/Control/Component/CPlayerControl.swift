import simd

/// Context-resolved command state for a player-controllable entity.
///
/// The Simulation Runtime writes these semantic values only after applying
/// authoritative selection. No physical key or button identity enters the row.
struct CPlayerControl: PComponent {
    var isInteractionActive: Bool
    var translation: SIMD2<Double>

    init(translation: SIMD2<Double> = .zero, isInteractionActive: Bool = false) {
        precondition(translation.isFinite, "Player translation intent must be finite.")
        self.translation = translation
        self.isInteractionActive = isInteractionActive
    }
}
