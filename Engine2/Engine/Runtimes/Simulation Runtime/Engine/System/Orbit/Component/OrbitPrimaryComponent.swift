/// Designates the gravity source used for one entity's orbital maneuvers.
///
/// The complete generational identity preserves the same source selection for
/// live estimates and command execution. It does not constrain the entity to
/// an analytic rail.
struct OrbitPrimaryComponent: Component {
    let primaryEntityID: EntityID
}

extension OrbitPrimaryComponent {
    @MainActor init?(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.orbitPrimaryID != nil) == (entity is OrbitCircularizable),
            "InitialState.orbitPrimaryID must be present exactly when the entity conforms to OrbitCircularizable."
        )
        guard let orbitPrimaryID = state.orbitPrimaryID else {
            return nil
        }
        self.init(primaryEntityID: orbitPrimaryID)
    }
}
