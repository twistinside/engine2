import simd

/// Authoritative ECS state container for one Simulation Runtime session.
///
/// `World` owns per-component sparse stores and simulation resources. Entity
/// objects expose typed facades over component rows, including lifecycle state.
/// Gameplay and lifecycle systems iterate stores directly. Registration is capability-driven:
/// `add(_:from:)` converts an entity's advertised protocols and validated seed
/// values into component rows at the ECS boundary.
class World {
    let components = Components()

    // MARK: Resources
    var camera = Camera.standard
    var cameraFollowEntityID: EntityID?
    var input = InputState()
    var collisionContacts: [CollisionContact] = []
    var collisionSweeps: [CollisionSweep] = []
    var orbitCircularizationCommand: OrbitCircularizationCommand?
    private(set) var selectedEntityID: EntityID?

    private var entitiesByID: [EntityID: Entity] = [:]
    private var reservedEntityIDs: Set<EntityID> = []
    private var nextEntityIndex = 0
    private let orbitCircularizationEstimateEvaluator = OrbitCircularizationEstimateEvaluator()

    /// Entity facades in deterministic identity order for UI and tooling.
    ///
    /// Each entity projects component data from World. Systems iterate component stores directly.
    var registeredEntities: [Entity] {
        entitiesByID.keys.sorted().compactMap {
            entitiesByID[$0]
        }
    }

    /// Captures this World's completed backend-neutral presentation facts.
    ///
    /// The authoritative owner performs this projection while the resulting
    /// ``SimulationPresentationSnapshot`` remains an isolation-independent
    /// immutable boundary value.
    func presentationSnapshot(at cursor: SimulationCursor) -> SimulationPresentationSnapshot {
        let entityPresentations = zip(
            components[RenderableComponent.self].entities,
            components[RenderableComponent.self].dense
        ).map { entity, renderable in
            EntityPresentationSnapshot(
                id: entity,
                position: components[PositionComponent.self][entity]?.position.singlePrecision,
                rotation: components[RotationComponent.self][entity]?.rotation,
                scale: components[ScaleComponent.self][entity]?.scale,
                meshID: renderable.meshID,
                materialID: renderable.materialID
            )
        }

        return SimulationPresentationSnapshot(
            cursor: cursor,
            camera: camera,
            entityPresentations: entityPresentations
        )
    }

    /// Creates the component rows implied by the entity's advertised capabilities.
    ///
    /// Capability protocols decide which component stores receive rows.
    /// Component initializers validate authored values and supply neutral
    /// control state, marker rows, and collision baselines. Orbital rails resolve
    /// their initial position and velocity from a registered primary before any
    /// rows are written. Rails cannot also supply explicit translational state
    /// or advertise dynamically integrated motion.
    ///
    /// Reject seed values for capabilities this entity does not expose. That
    /// keeps object APIs and ECS rows aligned instead of silently discarding
    /// caller intent.
    ///
    /// First registration requires an identity reserved by this World.
    /// Calling this method again for the same live entity reseeds its component
    /// rows without clearing pending removal. A destroyed identity cannot be
    /// registered again. Treat registration as construction; mutate existing
    /// gameplay state through the stores instead.
    @discardableResult
    func add(
        _ entity: Entity,
        from state: Entity.InitialState = .empty
    ) -> EntityID {
        precondition(entity.world === self, "An entity must register with its owning World.")
        precondition(
            entitiesByID[entity.id] === entity || reservedEntityIDs.contains(entity.id),
            "An entity requires a reserved identity or its existing live registration."
        )
        components.add(entity, from: state)
        register(entity)
        if state.selectionState == .selected {
            precondition(select(entity.id), "A selected seed requires a registered selectable entity")
        }
        return entity.id
    }

    /// Removes one registered entity and every component row it owns.
    ///
    /// Unknown or stale identities return `false` without changing live state.
    /// Destruction clears resources targeting the entity and removes it from
    /// subsequent presentations. Previously published snapshots remain valid.
    /// Scheduled gameplay marks lifecycle components; EntityRemovalSystem owns final collection.
    /// Callers performing immediate destruction must collect identities before this operation compacts stores.
    @discardableResult
    func destroy(_ entity: EntityID) -> Bool {
        guard entitiesByID.removeValue(forKey: entity) != nil else {
            return false
        }

        components.remove(entity)
        if selectedEntityID == entity {
            selectedEntityID = nil
        }
        if cameraFollowEntityID == entity {
            cameraFollowEntityID = nil
        }
        if orbitCircularizationCommand?.entityID == entity {
            orbitCircularizationCommand = nil
        }
        return true
    }

    /// Returns the facade registered for one complete generational identity.
    func entity(for id: EntityID) -> Entity? {
        entitiesByID[id]
    }

    /// Returns a live circularization estimate for one capable entity.
    func orbitCircularizationEstimate(for entity: EntityID) -> OrbitCircularizationEstimate? {
        orbitCircularizationEstimateEvaluator.estimate(for: entity, in: self)
    }

    /// Selects one registered selectable entity and clears every other row.
    ///
    /// Passing `nil` clears selection. An unknown or nonselectable identity is
    /// rejected without changing the current selection.
    @discardableResult
    func select(_ entity: EntityID?) -> Bool {
        if let entity,
           (entitiesByID[entity] == nil || components[SelectableComponent.self][entity] == nil) {
            return false
        }

        for candidate in components[SelectableComponent.self].entities {
            components[SelectableComponent.self].update(for: candidate) { selectable in
                selectable.selectionState = candidate == entity ? .selected : .unselected
            }
        }
        selectedEntityID = entity
        return true
    }

    private func register(_ entity: Entity) {
        if let existing = entitiesByID[entity.id] {
            precondition(
                existing === entity,
                "A different entity facade is already registered for ID: \(entity.id)"
            )
            return
        }
        entitiesByID[entity.id] = entity
        reservedEntityIDs.remove(entity.id)
    }

    /// Reserves a fresh identity without reusing a destroyed entity's index.
    func reserveEntityID() -> EntityID {
        let entityID = EntityID(index: nextEntityIndex, generation: 0)
        nextEntityIndex += 1
        reservedEntityIDs.insert(entityID)
        return entityID
    }
}
