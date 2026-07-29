/// Immutable Simulation Runtime presentation output for one committed cursor.
///
/// The snapshot preserves abstract presentation facts while excluding mutable
/// ECS storage, systems, clocks, tasks, and backend resources. Presentation
/// consumers own any private projection they derive from this value.
public nonisolated struct SimulationPresentationSnapshot: Equatable, Sendable {
    /// Exact committed Simulation state represented by this publication.
    public let cursor: SimulationCursor
    public let camera: Camera
    /// Observable state for entities that explicitly advertise presentation.
    public let entityPresentations: [EntityPresentationSnapshot]

    /// Tick-only migration view for consumers confined to one known session.
    public var tick: SimulationTick {
        cursor.tick
    }
}
