/// Open-ended display text for one entity.
///
/// Names are authored Game Content rather than a closed engine vocabulary, so
/// this component deliberately stores `String` instead of an enum.
struct DisplayNameComponent: Component {
    let value: String

    init(value: String) {
        precondition(!value.isEmpty, "An entity display name must not be empty.")
        self.value = value
    }
}

extension DisplayNameComponent {
    @MainActor init?(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.displayName != nil) == (entity is DisplayNamed),
            "InitialState.displayName must be present exactly when the entity conforms to DisplayNamed."
        )
        guard let displayName = state.displayName else {
            return nil
        }
        self.init(value: displayName)
    }
}
