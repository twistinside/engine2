/// World-space proximity range for an entity that accepts interaction.
struct InteractionComponent: Component {
    let interactionRange: Double

    init(interactionRange: Double) {
        precondition(
            interactionRange.isFinite && interactionRange > 0,
            "An interaction range must be finite and positive."
        )
        self.interactionRange = interactionRange
    }
}

extension InteractionComponent {
    @MainActor init?(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.interactionRange != nil) == (entity is Interactable),
            "InitialState.interactionRange must be present exactly when the entity conforms to Interactable."
        )
        guard let interactionRange = state.interactionRange else {
            return nil
        }
        self.init(interactionRange: interactionRange)
    }
}
