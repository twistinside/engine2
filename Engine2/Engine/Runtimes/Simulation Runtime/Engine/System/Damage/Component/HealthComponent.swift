/// Authoritative health for an entity that accepts damage independently of collision or targeting.
///
/// Construction requires positive health. Damage can exhaust it without removing the component;
/// the applying system requests deferred Entity removal after completing its effects.
struct HealthComponent: Component {
    private(set) var health: HitPoints

    init(health: HitPoints) {
        precondition(health.rawValue > 0, "Initial health must be positive.")
        self.health = health
    }

    /// Reduces current health by the supplied amount, retaining zero when damage exhausts it.
    mutating func applyDamage(_ amount: HitPoints) {
        health = HitPoints(rawValue: max(0, health.rawValue - amount.rawValue))
    }
}

extension HealthComponent {
    @MainActor init?(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.health != nil) == (entity is Damageable),
            "Damageable requires initial health; other entities must omit it."
        )
        guard let health = state.health else {
            return nil
        }
        self.init(health: HitPoints(rawValue: health))
    }
}
