/// World-space proximity range for an entity that accepts interaction.
struct CInteraction: PComponent {
    let interactionRange: Double

    init(interactionRange: Double) {
        precondition(
            interactionRange.isFinite && interactionRange > 0,
            "An interaction range must be finite and positive."
        )
        self.interactionRange = interactionRange
    }
}
