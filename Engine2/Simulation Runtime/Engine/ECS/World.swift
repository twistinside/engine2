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
    var interactionComponents = ComponentStore<CInteraction>()
    var massComponents = ComponentStore<CMass>()
    var mineableComponents = ComponentStore<CMineable>()
    var motionComponents = ComponentStore<CMotion>()
    var orbitCircularizationAutopilotComponents = ComponentStore<COrbitCircularizationAutopilot>()
    var orbitPrimaryComponents = ComponentStore<COrbitPrimary>()
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
    var orbitCircularizationCommand: OrbitCircularizationCommand?
    private(set) var selectedEntityID: EntityID?

    private var entitiesByID: [EntityID: Entity] = [:]
    private var nextEntityIndex = 0
    private let orbitCircularizationEstimateEvaluator = OrbitCircularizationEstimateEvaluator()

    /// Entity facades in deterministic identity order for UI and tooling.
    ///
    /// The returned objects project live component state. They are not a second
    /// authoritative entity store and systems must not use them for hot-path
    /// iteration.
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
    /// Seed the baseline transform rows first so higher-level capabilities
    /// such as motion and rotation always have their backing state.
    ///
    /// Reject seed values for capabilities this entity does not expose. That
    /// keeps object APIs and ECS rows aligned instead of silently discarding
    /// caller intent.
    @discardableResult
    func add(
        _ entity: Entity,
        from state: Entity.InitialState = .empty
    ) -> EntityID {
        addPositionComponent(for: entity, from: state)
        addMotionComponent(for: entity, from: state)
        addRotationComponent(for: entity, from: state)
        addAngularMotionComponents(for: entity, from: state)
        addScaleComponent(for: entity, from: state)
        addCargoComponent(for: entity, from: state)
        addCollisionComponents(for: entity, from: state)
        addDepotServiceComponent(for: entity, from: state)
        addDisplayNameComponent(for: entity, from: state)
        addFuelComponent(for: entity, from: state)
        addGravityReceiverComponent(for: entity, from: state)
        addGravitySourceComponent(for: entity, from: state)
        addInteractionComponent(for: entity, from: state)
        addMassComponent(for: entity, from: state)
        addMineableComponent(for: entity, from: state)
        addOrbitCircularizationComponents(for: entity, from: state)
        addOrbitalRailComponent(for: entity, from: state)
        addOreDepositComponent(for: entity, from: state)
        addPlayerControlComponent(for: entity, from: state)
        addPropulsionComponent(for: entity, from: state)
        addRenderableComponent(for: entity, from: state)
        addSelectionComponents(for: entity, from: state)
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

    private func addCargoComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.cargo != nil) == (entity is PCargoCarrying),
            "InitialState.cargo must be present exactly when the entity conforms to PCargoCarrying."
        )
        guard let cargo = state.cargo else {
            return
        }
        cargoComponents.insert(cargo, for: entity.id)
    }

    private func addCollisionComponents(for entity: Entity, from state: Entity.InitialState) {
        let isCollidable = entity is PCollidable
        precondition(
            (state.collisionBody != nil) == isCollidable,
            "InitialState.collisionBody must be present exactly when the entity conforms to PCollidable."
        )
        precondition(
            (state.previousPosition != nil) == isCollidable,
            "InitialState.previousPosition must be present exactly when the entity conforms to PCollidable."
        )
        guard let collisionBody = state.collisionBody,
              let previousPosition = state.previousPosition else {
            return
        }
        collisionBodyComponents.insert(collisionBody, for: entity.id)
        previousPositionComponents.insert(previousPosition, for: entity.id)
    }

    private func addDepotServiceComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.depotService != nil) == (entity is PDepotServicing),
            "InitialState.depotService must be present exactly when the entity conforms to PDepotServicing."
        )
        guard let depotService = state.depotService else {
            return
        }
        depotServiceComponents.insert(depotService, for: entity.id)
    }

    private func addDisplayNameComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.displayName != nil) == (entity is PDisplayNamed),
            "InitialState.displayName must be present exactly when the entity conforms to PDisplayNamed."
        )
        guard let displayName = state.displayName else {
            return
        }
        displayNameComponents.insert(displayName, for: entity.id)
    }

    private func addFuelComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.fuel != nil) == (entity is PFueled),
            "InitialState.fuel must be present exactly when the entity conforms to PFueled."
        )
        guard let fuel = state.fuel else {
            return
        }
        fuelComponents.insert(fuel, for: entity.id)
    }

    private func addGravityReceiverComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.gravityReceiver != nil) == (entity is PGravityAffected),
            "InitialState.gravityReceiver must be present exactly when the entity conforms to PGravityAffected."
        )
        guard let gravityReceiver = state.gravityReceiver else {
            return
        }
        gravityReceiverComponents.insert(gravityReceiver, for: entity.id)
    }

    private func addGravitySourceComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.gravitySource != nil) == (entity is PGravitySource),
            "InitialState.gravitySource must be present exactly when the entity conforms to PGravitySource."
        )
        guard let gravitySource = state.gravitySource else {
            return
        }
        gravitySourceComponents.insert(gravitySource, for: entity.id)
    }

    private func addInteractionComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.interaction != nil) == (entity is PInteractable),
            "InitialState.interaction must be present exactly when the entity conforms to PInteractable."
        )
        guard let interaction = state.interaction else {
            return
        }
        interactionComponents.insert(interaction, for: entity.id)
    }

    private func addMassComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.mass != nil) == (entity is PLiveMass),
            "InitialState.mass must be present exactly when the entity conforms to PLiveMass."
        )
        guard let mass = state.mass else {
            return
        }
        massComponents.insert(mass, for: entity.id)
    }

    private func addMineableComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.mineable != nil) == (entity is PMineable),
            "InitialState.mineable must be present exactly when the entity conforms to PMineable."
        )
        guard let mineable = state.mineable else {
            return
        }
        mineableComponents.insert(mineable, for: entity.id)
    }

    private func addOrbitCircularizationComponents(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.orbitPrimary != nil) == (entity is POrbitCircularizable),
            "InitialState.orbitPrimary must be present exactly when the entity conforms to POrbitCircularizable."
        )
        guard let orbitPrimary = state.orbitPrimary else {
            return
        }
        orbitPrimaryComponents.insert(orbitPrimary, for: entity.id)
        orbitCircularizationAutopilotComponents.insert(.idle, for: entity.id)
    }

    private func addOrbitalRailComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.orbitalRail != nil) == (entity is POrbiting),
            "InitialState.orbitalRail must be present exactly when the entity conforms to POrbiting."
        )
        guard let orbitalRail = state.orbitalRail else {
            return
        }
        orbitalRailComponents.insert(orbitalRail, for: entity.id)
    }

    private func addOreDepositComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.oreDeposit != nil) == (entity is POreContaining),
            "InitialState.oreDeposit must be present exactly when the entity conforms to POreContaining."
        )
        guard let oreDeposit = state.oreDeposit else {
            return
        }
        oreDepositComponents.insert(oreDeposit, for: entity.id)
    }

    private func addPlayerControlComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.playerControl != nil) == (entity is PPlayerControlled),
            "InitialState.playerControl must be present exactly when the entity conforms to PPlayerControlled."
        )
        guard let playerControl = state.playerControl else {
            return
        }
        playerControlComponents.insert(playerControl, for: entity.id)
    }

    private func addPropulsionComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.propulsion != nil) == (entity is PPropelled),
            "InitialState.propulsion must be present exactly when the entity conforms to PPropelled."
        )
        guard let propulsion = state.propulsion else {
            return
        }
        propulsionComponents.insert(propulsion, for: entity.id)
    }

    private func addRenderableComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.renderable != nil) == (entity is PRenderable),
            "InitialState.renderable must be present exactly when the entity conforms to PRenderable."
        )
        guard let renderableState = state.renderable else {
            return
        }

        let renderable = CRenderable(
            meshID: renderableState.meshID,
            materialID: renderableState.materialID
        )
        renderableComponents.insert(renderable, for: entity.id)
    }

    private func addSelectionComponents(for entity: Entity, from state: Entity.InitialState) {
        let isSelectable = entity is PSelectable
        precondition(
            state.selectionState == nil || isSelectable,
            "Initial state.selectionState requires PSelectable conformance"
        )
        precondition(
            (state.selectionBounds != nil) == isSelectable,
            "InitialState.selectionBounds must be present exactly when the entity conforms to PSelectable."
        )
        guard let selectionBounds = state.selectionBounds else {
            return
        }

        let selectionState: CSelectable.SelectionState = selectedEntityID == entity.id
            ? .selected
            : state.selectionState ?? .unselected
        let selectable = CSelectable(selectionState: selectionState)
        selectableComponents.insert(selectable, for: entity.id)
        selectionBoundsComponents.insert(selectionBounds, for: entity.id)
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

    func reserveEntityID() -> EntityID {
        // Until entity destruction exists, each reservation consumes a fresh
        // index so entity identities never alias a previous live row.
        let entityID = EntityID(index: nextEntityIndex, generation: 0)
        nextEntityIndex += 1
        return entityID
    }
}
