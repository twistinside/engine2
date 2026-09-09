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
    var angularMotionAccumulatorComponents = ComponentStore<AngularMotionAccumulatorComponent>()
    var angularVelocityComponents = ComponentStore<AngularVelocityComponent>()
    var cargoComponents = ComponentStore<CargoComponent>()
    var collisionBodyComponents = ComponentStore<CollisionBodyComponent>()
    var depotServiceComponents = ComponentStore<DepotServiceComponent>()
    var destructibleComponents = ComponentStore<DestructibleComponent>()
    var displayNameComponents = ComponentStore<DisplayNameComponent>()
    var fuelComponents = ComponentStore<FuelComponent>()
    var gravityReceiverComponents = ComponentStore<GravityReceiverComponent>()
    var gravitySourceComponents = ComponentStore<GravitySourceComponent>()
    var interactionComponents = ComponentStore<InteractionComponent>()
    var massComponents = ComponentStore<MassComponent>()
    var mineableComponents = ComponentStore<MineableComponent>()
    var fireableComponents = ComponentStore<FireableComponent>()
    var ownershipComponents = ComponentStore<OwnershipComponent>()
    var lifetimeComponents = ComponentStore<LifetimeComponent>()
    var missileLauncherComponents = ComponentStore<MissileLauncherComponent>()
    var motionComponents = ComponentStore<MotionComponent>()
    var orbitCircularizationAutopilotComponents = ComponentStore<OrbitCircularizationAutopilotComponent>()
    var orbitPrimaryComponents = ComponentStore<OrbitPrimaryComponent>()
    var orbitalRailComponents = ComponentStore<OrbitalRailComponent>()
    var oreDepositComponents = ComponentStore<OreDepositComponent>()
    var playerControlComponents = ComponentStore<PlayerControlComponent>()
    var positionComponents = ComponentStore<PositionComponent>()
    var previousPositionComponents = ComponentStore<PreviousPositionComponent>()
    var propulsionComponents = ComponentStore<PropulsionComponent>()
    var renderableComponents = ComponentStore<RenderableComponent>()
    var rotationComponents = ComponentStore<RotationComponent>()
    var scaleComponents = ComponentStore<ScaleComponent>()
    var selectableComponents = ComponentStore<SelectableComponent>()
    var selectionBoundsComponents = ComponentStore<SelectionBoundsComponent>()

    // MARK: Resources
    var camera = Camera.standard
    var cameraFollowEntityID: EntityID?
    var input = InputState()
    var orbitCircularizationCommand: OrbitCircularizationCommand?
    private(set) var selectedEntityID: EntityID?

    private var entitiesByID: [EntityID: Entity] = [:]
    private var reservedEntityIDs: Set<EntityID> = []
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
    ///
    /// First registration requires an identity reserved by this World.
    /// Calling this method again for the same live entity reseeds its component
    /// rows. A destroyed identity cannot be registered again. Treat registration
    /// as construction; mutate existing gameplay state through the stores instead.
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
        addPositionComponent(for: entity, from: state)
        addMotionComponent(for: entity, from: state)
        addRotationComponent(for: entity, from: state)
        addAngularMotionComponents(for: entity, from: state)
        addScaleComponent(for: entity, from: state)
        addCargoComponent(for: entity, from: state)
        addCollisionComponents(for: entity, from: state)
        addDepotServiceComponent(for: entity, from: state)
        addDestructibleComponent(for: entity, from: state)
        addDisplayNameComponent(for: entity, from: state)
        addFuelComponent(for: entity, from: state)
        addGravityReceiverComponent(for: entity, from: state)
        addGravitySourceComponent(for: entity, from: state)
        addInteractionComponent(for: entity, from: state)
        addMassComponent(for: entity, from: state)
        addMineableComponent(for: entity, from: state)
        addFireableComponent(for: entity, from: state)
        addOwnershipComponent(for: entity, from: state)
        addLifetimeComponent(for: entity, from: state)
        addMissileLauncherComponent(for: entity, from: state)
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

    /// Removes one registered entity and every component row it owns.
    ///
    /// Unknown or stale identities return `false` without changing live state.
    /// Destruction clears resources targeting the entity and removes it from
    /// subsequent presentations. Previously published snapshots remain valid.
    /// Systems must collect identities before destruction can compact stores.
    @discardableResult
    func destroy(_ entity: EntityID) -> Bool {
        guard entitiesByID.removeValue(forKey: entity) != nil else {
            return false
        }

        removeComponents(for: entity)
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

    private func removeComponents(for entity: EntityID) {
        angularMotionAccumulatorComponents.remove(for: entity)
        angularVelocityComponents.remove(for: entity)
        cargoComponents.remove(for: entity)
        collisionBodyComponents.remove(for: entity)
        depotServiceComponents.remove(for: entity)
        destructibleComponents.remove(for: entity)
        displayNameComponents.remove(for: entity)
        fuelComponents.remove(for: entity)
        gravityReceiverComponents.remove(for: entity)
        gravitySourceComponents.remove(for: entity)
        interactionComponents.remove(for: entity)
        massComponents.remove(for: entity)
        mineableComponents.remove(for: entity)
        fireableComponents.remove(for: entity)
        ownershipComponents.remove(for: entity)
        lifetimeComponents.remove(for: entity)
        missileLauncherComponents.remove(for: entity)
        motionComponents.remove(for: entity)
        orbitCircularizationAutopilotComponents.remove(for: entity)
        orbitPrimaryComponents.remove(for: entity)
        orbitalRailComponents.remove(for: entity)
        oreDepositComponents.remove(for: entity)
        playerControlComponents.remove(for: entity)
        positionComponents.remove(for: entity)
        previousPositionComponents.remove(for: entity)
        propulsionComponents.remove(for: entity)
        renderableComponents.remove(for: entity)
        rotationComponents.remove(for: entity)
        scaleComponents.remove(for: entity)
        selectableComponents.remove(for: entity)
        selectionBoundsComponents.remove(for: entity)
    }

    private func addPositionComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            state.position == nil || entity is Positionable,
            "Initial state.position requires Positionable conformance"
        )
        guard entity is Positionable else {
            return
        }

        let position = PositionComponent(position: state.position ?? .zero)
        positionComponents.insert(position, for: entity.id)
    }

    private func addMotionComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (
                state.velocity == nil &&
                state.accelerationIntent == nil &&
                state.impulse == nil
            ) || entity is Movable,
            "Initial movement state requires Movable conformance"
        )
        guard entity is Movable else {
            return
        }

        let motion = MotionComponent(
            velocity: state.velocity ?? .zero,
            accelerationIntent: state.accelerationIntent ?? .idle,
            impulse: state.impulse ?? .zero
        )
        motionComponents.insert(motion, for: entity.id)
    }

    private func addRotationComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            state.rotation == nil || entity is Orientable,
            "Initial state.rotation requires Orientable conformance"
        )
        guard entity is Orientable else {
            return
        }

        let rotation = state.rotation.map { RotationComponent(rotation: $0) } ?? .identity
        rotationComponents.insert(rotation, for: entity.id)
    }

    private func addAngularMotionComponents(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (
                state.angularVelocity == nil &&
                state.angularAcceleration == nil &&
                state.angularImpulse == nil
            ) || entity is Rotatable,
            "Initial angular state requires Rotatable conformance"
        )
        guard entity is Rotatable else {
            return
        }

        let angularVelocity = AngularVelocityComponent(
            angularVelocity: state.angularVelocity ?? .zero
        )
        angularVelocityComponents.insert(angularVelocity, for: entity.id)

        let angularMotionAccumulator = AngularMotionAccumulatorComponent(
            angularAcceleration: state.angularAcceleration ?? .zero,
            angularImpulse: state.angularImpulse ?? .zero
        )
        angularMotionAccumulatorComponents.insert(angularMotionAccumulator, for: entity.id)
    }

    private func addScaleComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            state.scale == nil || entity is Scalable,
            "Initial state.scale requires Scalable conformance"
        )
        guard entity is Scalable else {
            return
        }

        let scale = ScaleComponent(scale: state.scale ?? SIMD3<Float>(repeating: 1))
        scaleComponents.insert(scale, for: entity.id)
    }

    private func addCargoComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.cargo != nil) == (entity is CargoCarrying),
            "InitialState.cargo must be present exactly when the entity conforms to CargoCarrying."
        )
        guard let cargo = state.cargo else {
            return
        }
        cargoComponents.insert(cargo, for: entity.id)
    }

    private func addCollisionComponents(for entity: Entity, from state: Entity.InitialState) {
        let isCollidable = entity is Collidable
        precondition(
            (state.collisionBody != nil) == isCollidable,
            "InitialState.collisionBody must be present exactly when the entity conforms to Collidable."
        )
        precondition(
            (state.previousPosition != nil) == isCollidable,
            "InitialState.previousPosition must be present exactly when the entity conforms to Collidable."
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
            (state.depotService != nil) == (entity is DepotServicing),
            "InitialState.depotService must be present exactly when the entity conforms to DepotServicing."
        )
        guard let depotService = state.depotService else {
            return
        }
        depotServiceComponents.insert(depotService, for: entity.id)
    }

    private func addDestructibleComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.destructible != nil) == (entity is Destructible),
            "InitialState.destructible must be present exactly when the entity conforms to Destructible."
        )
        guard let destructible = state.destructible else {
            return
        }
        destructibleComponents.insert(destructible, for: entity.id)
    }

    private func addDisplayNameComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.displayName != nil) == (entity is DisplayNamed),
            "InitialState.displayName must be present exactly when the entity conforms to DisplayNamed."
        )
        guard let displayName = state.displayName else {
            return
        }
        displayNameComponents.insert(displayName, for: entity.id)
    }

    private func addFuelComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.fuel != nil) == (entity is Fueled),
            "InitialState.fuel must be present exactly when the entity conforms to Fueled."
        )
        guard let fuel = state.fuel else {
            return
        }
        fuelComponents.insert(fuel, for: entity.id)
    }

    private func addGravityReceiverComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.gravityReceiver != nil) == (entity is GravityAffected),
            "InitialState.gravityReceiver must be present exactly when the entity conforms to GravityAffected."
        )
        guard let gravityReceiver = state.gravityReceiver else {
            return
        }
        gravityReceiverComponents.insert(gravityReceiver, for: entity.id)
    }

    private func addGravitySourceComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.gravitySource != nil) == (entity is GravitySource),
            "InitialState.gravitySource must be present exactly when the entity conforms to GravitySource."
        )
        guard let gravitySource = state.gravitySource else {
            return
        }
        gravitySourceComponents.insert(gravitySource, for: entity.id)
    }

    private func addInteractionComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.interaction != nil) == (entity is Interactable),
            "InitialState.interaction must be present exactly when the entity conforms to Interactable."
        )
        guard let interaction = state.interaction else {
            return
        }
        interactionComponents.insert(interaction, for: entity.id)
    }

    private func addMassComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.mass != nil) == (entity is LiveMass),
            "InitialState.mass must be present exactly when the entity conforms to LiveMass."
        )
        guard let mass = state.mass else {
            return
        }
        massComponents.insert(mass, for: entity.id)
    }

    private func addMineableComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.mineable != nil) == (entity is Mineable),
            "InitialState.mineable must be present exactly when the entity conforms to Mineable."
        )
        guard let mineable = state.mineable else {
            return
        }
        mineableComponents.insert(mineable, for: entity.id)
    }

    private func addFireableComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.fireable != nil) == (entity is Fireable),
            "InitialState.fireable must be present exactly when the entity conforms to Fireable."
        )
        guard let fireable = state.fireable else {
            return
        }
        fireableComponents.insert(fireable, for: entity.id)
    }

    private func addOwnershipComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.ownership != nil) == (entity is Ownable),
            "InitialState.ownership must be present exactly when the entity conforms to Ownable."
        )
        guard let ownership = state.ownership else {
            return
        }
        ownershipComponents.insert(ownership, for: entity.id)
    }

    private func addLifetimeComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.lifetime != nil) == (entity is Expirable),
            "InitialState.lifetime must be present exactly when the entity conforms to Expirable."
        )
        guard let lifetime = state.lifetime else {
            return
        }
        lifetimeComponents.insert(lifetime, for: entity.id)
    }

    private func addMissileLauncherComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.missileLauncher != nil) == (entity is MissileLaunching),
            "InitialState.missileLauncher must be present exactly when the entity conforms to MissileLaunching."
        )
        guard let missileLauncher = state.missileLauncher else {
            return
        }
        missileLauncherComponents.insert(missileLauncher, for: entity.id)
    }

    private func addOrbitCircularizationComponents(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.orbitPrimary != nil) == (entity is OrbitCircularizable),
            "InitialState.orbitPrimary must be present exactly when the entity conforms to OrbitCircularizable."
        )
        guard let orbitPrimary = state.orbitPrimary else {
            return
        }
        orbitPrimaryComponents.insert(orbitPrimary, for: entity.id)
        orbitCircularizationAutopilotComponents.insert(.idle, for: entity.id)
    }

    private func addOrbitalRailComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.orbitalRail != nil) == (entity is Orbiting),
            "InitialState.orbitalRail must be present exactly when the entity conforms to Orbiting."
        )
        guard let orbitalRail = state.orbitalRail else {
            return
        }
        orbitalRailComponents.insert(orbitalRail, for: entity.id)
    }

    private func addOreDepositComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.oreDeposit != nil) == (entity is OreContaining),
            "InitialState.oreDeposit must be present exactly when the entity conforms to OreContaining."
        )
        guard let oreDeposit = state.oreDeposit else {
            return
        }
        oreDepositComponents.insert(oreDeposit, for: entity.id)
    }

    private func addPlayerControlComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.playerControl != nil) == (entity is PlayerControlled),
            "InitialState.playerControl must be present exactly when the entity conforms to PlayerControlled."
        )
        guard let playerControl = state.playerControl else {
            return
        }
        playerControlComponents.insert(playerControl, for: entity.id)
    }

    private func addPropulsionComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.propulsion != nil) == (entity is Propelled),
            "InitialState.propulsion must be present exactly when the entity conforms to Propelled."
        )
        guard let propulsion = state.propulsion else {
            return
        }
        propulsionComponents.insert(propulsion, for: entity.id)
    }

    private func addRenderableComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.renderable != nil) == (entity is Renderable),
            "InitialState.renderable must be present exactly when the entity conforms to Renderable."
        )
        guard let renderableState = state.renderable else {
            return
        }

        let renderable = RenderableComponent(
            meshID: renderableState.meshID,
            materialID: renderableState.materialID
        )
        renderableComponents.insert(renderable, for: entity.id)
    }

    private func addSelectionComponents(for entity: Entity, from state: Entity.InitialState) {
        let isSelectable = entity is Selectable
        precondition(
            state.selectionState == nil || isSelectable,
            "Initial state.selectionState requires Selectable conformance"
        )
        precondition(
            (state.selectionBounds != nil) == isSelectable,
            "InitialState.selectionBounds must be present exactly when the entity conforms to Selectable."
        )
        guard let selectionBounds = state.selectionBounds else {
            return
        }

        let selectionState: SelectableComponent.SelectionState = selectedEntityID == entity.id
            ? .selected
            : state.selectionState ?? .unselected
        let selectable = SelectableComponent(selectionState: selectionState)
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
