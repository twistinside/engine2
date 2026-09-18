/// Positive Newtonian gravitational parameter supplied by one source entity.
///
/// The value uses cubic meters per second squared. Carrying `mu` directly lets
/// fictional Game Content choose compact orbital scales without inventing a
/// second authoritative mass solely for gravity.
struct GravitySourceComponent: Component {
    let gravitationalParameter: Double

    init(gravitationalParameter: Double) {
        precondition(
            gravitationalParameter.isFinite && gravitationalParameter > 0,
            "A gravitational parameter must be finite and positive."
        )
        self.gravitationalParameter = gravitationalParameter
    }
}

extension GravitySourceComponent {
    @MainActor init?(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.gravitationalParameter != nil) == (entity is GravitySource),
            "InitialState.gravitationalParameter must be present exactly when the entity conforms to GravitySource."
        )
        guard let gravitationalParameter = state.gravitationalParameter else {
            return nil
        }
        self.init(gravitationalParameter: gravitationalParameter)
    }
}
