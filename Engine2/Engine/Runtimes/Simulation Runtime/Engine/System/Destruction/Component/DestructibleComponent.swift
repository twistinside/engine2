/// Authoritative lifecycle state for every registered entity.
///
/// World creates an active row on first registration. Systems set pendingRemoval to
/// request final collection without removing rows that later systems may still inspect.
/// Reseeding preserves this state; EntityRemovalSystem collects pending identities.
struct DestructibleComponent: Component {
    var state: State = .active

    /// Lifecycle state retained until final collection removes the component row.
    ///
    /// An absent component represents an unregistered or removed identity.
    nonisolated enum State: Codable, Equatable, Sendable {
        case active
        case pendingRemoval
    }
}

extension DestructibleComponent {
    @MainActor init?(for entity: Entity, from state: Entity.InitialState) {
        if entity.world.entity(for: entity.id) === entity,
           let existing = entity.world.components[Self.self][entity.id] {
            self = existing
        } else {
            self.init()
        }
    }
}
