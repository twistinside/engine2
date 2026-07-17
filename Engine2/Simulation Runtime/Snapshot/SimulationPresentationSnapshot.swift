/// Immutable Simulation Runtime presentation output for one completed tick.
///
/// The snapshot preserves abstract presentation facts while excluding mutable
/// ECS storage, systems, clocks, tasks, and backend resources. Presentation
/// consumers own any private projection they derive from this value.
struct SimulationPresentationSnapshot: Equatable {
    let tick: SimulationTick
    let camera: Camera
    /// Observable state for entities that explicitly advertise presentation.
    let entityPresentations: [EntityPresentationSnapshot]

    /// Captures the world's completed abstract presentation facts.
    static func capture(
        from world: World,
        at tick: SimulationTick
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
                meshID: renderable.meshID
            )
        }

        return SimulationPresentationSnapshot(
            tick: tick,
            camera: world.camera,
            entityPresentations: entityPresentations
        )
    }
}
