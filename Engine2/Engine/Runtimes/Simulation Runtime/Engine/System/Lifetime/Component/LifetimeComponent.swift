/// Remaining simulation time before an entity expires, independent of its other capabilities.
struct LifetimeComponent: Component {
    var remainingLifetime: Double

    init(remainingLifetime: Double) {
        precondition(
            remainingLifetime.isFinite && remainingLifetime > 0,
            "Remaining lifetime must be finite and positive."
        )
        self.remainingLifetime = remainingLifetime
    }
}

extension LifetimeComponent {
    @MainActor init?(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.lifetime != nil) == (entity is Expirable),
            "InitialState.lifetime must be present exactly when the entity conforms to Expirable."
        )
        guard let lifetime = state.lifetime else {
            return nil
        }
        self.init(remainingLifetime: lifetime)
    }
}
