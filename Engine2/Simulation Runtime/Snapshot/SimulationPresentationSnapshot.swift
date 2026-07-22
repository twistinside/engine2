/// Immutable Simulation Runtime presentation output for one committed cursor.
///
/// The snapshot preserves abstract presentation facts while excluding mutable
/// ECS storage, systems, clocks, tasks, and backend resources. Presentation
/// consumers own any private projection they derive from this value.
nonisolated struct SimulationPresentationSnapshot: Equatable, Sendable {
    /// Exact committed Simulation state represented by this publication.
    let cursor: SimulationCursor
    let camera: Camera
    /// Observable state for entities that explicitly advertise presentation.
    let entityPresentations: [EntityPresentationSnapshot]

    /// Tick-only migration view for consumers confined to one known session.
    var tick: SimulationTick {
        cursor.tick
    }

    /// Captures the world's completed abstract presentation facts.
    @MainActor
    static func capture(
        from world: World,
        at cursor: SimulationCursor
    ) -> SimulationPresentationSnapshot {
        // Presentation state drives this boundary. ComponentStore keeps its
        // entity IDs aligned with dense component rows, so iterate both once
        // and join the optional transform facts in the published contract.
        let entityPresentations = zip(
            world.renderableComponents.entities,
            world.renderableComponents.dense
        ).map { entity, renderable in
            EntityPresentationSnapshot(
                id: entity,
                position: world.positionComponents[entity]?.position,
                rotation: world.rotationComponents[entity]?.rotation,
                scale: world.scaleComponents[entity]?.scale,
                meshID: renderable.meshID,
                materialID: renderable.materialID
            )
        }

        return SimulationPresentationSnapshot(
            cursor: cursor,
            camera: world.camera,
            entityPresentations: entityPresentations
        )
    }
}
