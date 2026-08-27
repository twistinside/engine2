import simd

/// Authoritative ECS state container for one Simulation Runtime session.
///
/// `World` owns per-component sparse stores and simulation resources. Entity
/// objects are only typed facades over these rows, while systems operate on the
/// stores directly. Registration is capability-driven: `add(_:from:)` converts
/// an entity's advertised protocols and validated seed values into component
/// rows at the ECS boundary.
class World {
    // MARK: Components
    var angularMotionAccumulatorComponents = ComponentStore<CAngularMotionAccumulator>()
    var angularVelocityComponents = ComponentStore<CAngularVelocity>()
    var cargoComponents = ComponentStore<CCargo>()
    var collisionBodyComponents = ComponentStore<CCollisionBody>()
    var depotServiceComponents = ComponentStore<CDepotService>()
    var displayNameComponents = ComponentStore<CDisplayName>()
    var fuelComponents = ComponentStore<CFuel>()
    var gravityReceiverComponents = ComponentStore<CGravityReceiver>()
    var gravitySourceComponents = ComponentStore<CGravitySource>()
    var massComponents = ComponentStore<CMass>()
    var mineableComponents = ComponentStore<CMineable>()
    var motionComponents = ComponentStore<CMotion>()
    var orbitalRailComponents = ComponentStore<COrbitalRail>()
    var oreDepositComponents = ComponentStore<COreDeposit>()
    var playerControlComponents = ComponentStore<CPlayerControl>()
    var positionComponents = ComponentStore<CPosition>()
    var previousPositionComponents = ComponentStore<CPreviousPosition>()
    var propulsionComponents = ComponentStore<CPropulsion>()
    var renderableComponents = ComponentStore<CRenderable>()
    var rotationComponents = ComponentStore<CRotation>()
    var scaleComponents = ComponentStore<CScale>()
    var selectableComponents = ComponentStore<CSelectable>()
    var selectionBoundsComponents = ComponentStore<CSelectionBounds>()

    // MARK: Resources
    var camera = Camera.standard
    var cameraFollowEntityID: EntityID?
    var input = InputState()
    var inputHistory = InputHistory(maximumEntryCount: 60)
    private(set) var selectedEntityID: EntityID?

    private var entitiesByID: [EntityID: Entity] = [:]
    private var nextEntityIndex = 0

    /// Entity facades in deterministic identity order for UI and tooling.
    ///
    /// The returned objects project live component state. They are not a second
    /// authoritative entity store and systems must not use them for hot-path
    /// iteration.
    var registeredEntities: [Entity] {
        entitiesByID.keys.sorted(by: entityIDPrecedes).compactMap {
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
            renderableComponents.entities,
            renderableComponents.dense
        ).map { entity, renderable in
            EntityPresentationSnapshot(
                id: entity,
                position: positionComponents[entity]?.position.singlePrecision,
                rotation: rotationComponents[entity]?.rotation,
                scale: scaleComponents[entity]?.scale,
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
    /// Capability protocols decide which component stores receive rows; the
    /// optional initial values only supply the seeds for those rows.
    /// `renderableState` is required exactly when the entity advertises
    /// `PRenderable`, keeping Game Content's mesh/material choice out of the
    /// live capability protocol.
    ///
    /// Seed the baseline transform rows first so higher-level capabilities
    /// such as motion and rotation always have their backing state.
    ///
    /// Reject seed values for capabilities this entity does not expose. That
    /// keeps object APIs and ECS rows aligned instead of silently discarding
    /// caller intent.
    @discardableResult
    func add(
        _ entity: Entity,
        from state: Entity.InitialState = .empty,
        renderable renderableState: RenderableInitialState? = nil
    ) -> EntityID {
        addPositionComponent(for: entity, from: state)
        addMotionComponent(for: entity, from: state)
        addRotationComponent(for: entity, from: state)
        addAngularMotionComponents(for: entity, from: state)
        addScaleComponent(for: entity, from: state)
        addRenderableComponent(for: entity, from: renderableState)
        addSelectionComponent(for: entity, from: state)
        register(entity)
        if state.selectionState == .selected {
            precondition(select(entity.id), "A selected seed requires a registered selectable entity")
        }
        return entity.id
    }

    /// Returns the facade registered for one complete generational identity.
    func entity(for id: EntityID) -> Entity? {
        entitiesByID[id]
    }

    /// Returns dry mass plus current propellant and cargo mass.
    ///
    /// Missing optional storage contributes zero. A missing mass row means the
    /// entity does not advertise live mass.
    func liveMass(for entity: EntityID) -> Double? {
        guard let mass = massComponents[entity] else {
            return nil
        }

        return mass.dryMass
            + (fuelComponents[entity]?.remaining ?? 0)
            + (cargoComponents[entity]?.ore ?? 0)
    }

    /// Selects one registered selectable entity and clears every other row.
    ///
    /// Passing `nil` clears selection. An unknown or nonselectable identity is
    /// rejected without changing the current selection.
    @discardableResult
    func select(_ entity: EntityID?) -> Bool {
        if let entity,
           (entitiesByID[entity] == nil || selectableComponents[entity] == nil) {
            return false
        }

        for candidate in selectableComponents.entities {
            selectableComponents.update(for: candidate) { selectable in
                selectable.selectionState = candidate == entity ? .selected : .unselected
            }
        }
        selectedEntityID = entity
        return true
    }

    private func addPositionComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            state.position == nil || entity is PPositionable,
            "Initial state.position requires PPositionable conformance"
        )
        guard entity is PPositionable else {
            return
        }

        let position = CPosition(position: state.position ?? .zero)
        positionComponents.insert(position, for: entity.id)
    }

    private func addMotionComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (
                state.velocity == nil &&
                state.accelerationIntent == nil &&
                state.impulse == nil
            ) || entity is PMovable,
            "Initial movement state requires PMovable conformance"
        )
        guard entity is PMovable else {
            return
        }

        let motion = CMotion(
            velocity: state.velocity ?? .zero,
            accelerationIntent: state.accelerationIntent ?? .idle,
            impulse: state.impulse ?? .zero
        )
        motionComponents.insert(motion, for: entity.id)
    }

    private func addRotationComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            state.rotation == nil || entity is POrientable,
            "Initial state.rotation requires POrientable conformance"
        )
        guard entity is POrientable else {
            return
        }

        let rotation = state.rotation.map { CRotation(rotation: $0) } ?? .identity
        rotationComponents.insert(rotation, for: entity.id)
    }

    private func addAngularMotionComponents(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (
                state.angularVelocity == nil &&
                state.angularAcceleration == nil &&
                state.angularImpulse == nil
            ) || entity is PRotatable,
            "Initial angular state requires PRotatable conformance"
        )
        guard entity is PRotatable else {
            return
        }

        let angularVelocity = CAngularVelocity(
            angularVelocity: state.angularVelocity ?? .zero
        )
        angularVelocityComponents.insert(angularVelocity, for: entity.id)

        let angularMotionAccumulator = CAngularMotionAccumulator(
            angularAcceleration: state.angularAcceleration ?? .zero,
            angularImpulse: state.angularImpulse ?? .zero
        )
        angularMotionAccumulatorComponents.insert(angularMotionAccumulator, for: entity.id)
    }

    private func addScaleComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            state.scale == nil || entity is PScalable,
            "Initial state.scale requires PScalable conformance"
        )
        guard entity is PScalable else {
            return
        }

        let scale = CScale(scale: state.scale ?? SIMD3<Float>(repeating: 1))
        scaleComponents.insert(scale, for: entity.id)
    }

    private func addRenderableComponent(for entity: Entity, from renderableState: RenderableInitialState?) {
        precondition(
            renderableState == nil || entity is PRenderable,
            "Renderable initial state requires PRenderable conformance"
        )
        precondition(
            !(entity is PRenderable) || renderableState != nil,
            "PRenderable conformance requires renderable initial state"
        )
        guard let renderableState else {
            return
        }

        let renderable = CRenderable(
            meshID: renderableState.meshID,
            materialID: renderableState.materialID
        )
        renderableComponents.insert(renderable, for: entity.id)
    }

    private func addSelectionComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            state.selectionState == nil || entity is PSelectable,
            "Initial state.selectionState requires PSelectable conformance"
        )
        guard entity is PSelectable else {
            return
        }

        let selectionState: CSelectable.SelectionState = selectedEntityID == entity.id
            ? .selected
            : state.selectionState ?? .unselected
        let selectable = CSelectable(selectionState: selectionState)
        selectableComponents.insert(selectable, for: entity.id)
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
    }

    private func entityIDPrecedes(_ lhs: EntityID, _ rhs: EntityID) -> Bool {
        if lhs.index == rhs.index {
            return lhs.generation < rhs.generation
        }
        return lhs.index < rhs.index
    }

    func reserveEntityID() -> EntityID {
        // Until entity destruction exists, each reservation consumes a fresh
        // index so entity identities never alias a previous live row.
        let entityID = EntityID(index: nextEntityIndex, generation: 0)
        nextEntityIndex += 1
        return entityID
    }
}
