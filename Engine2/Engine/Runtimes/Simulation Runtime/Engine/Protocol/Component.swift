/// An ECS value with capability-based construction and typed removal.
///
/// Values and their Codable and Equatable witnesses are isolation-independent.
/// Entity-aware construction and World-owned storage belong to the main actor.
nonisolated protocol Component: Codable, Equatable {
    /// Creates the row for an advertised capability, or returns nil when absent.
    ///
    /// Initializers validate authored seeds. Dependencies on other rows must
    /// follow the construction order declared by Components.types; no initializer
    /// may read its own live capability accessors before its row exists.
    @MainActor init?(for entity: Entity, from state: Entity.InitialState)

    /// Removes this component for an exact entity identity, if present.
    @MainActor static func remove(for entity: EntityID, from components: Components)
}

extension Component {
    @MainActor static func remove(for entity: EntityID, from components: Components) {
        components[Self.self].remove(for: entity)
    }
}
