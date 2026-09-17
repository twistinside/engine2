/// An ECS value with capability-based construction.
///
/// Values and their Codable and Equatable witnesses are isolation-independent.
/// Entity-aware construction belongs to the main actor.
nonisolated protocol Component: Codable, Equatable {
    /// Creates the row for an advertised capability, or returns nil when absent.
    ///
    /// Initializers validate authored seeds. Dependencies on other rows must
    /// follow the construction order declared by Components.types; no initializer
    /// may read its own live capability accessors before its row exists.
    @MainActor init?(for entity: Entity, from state: Entity.InitialState)
}
