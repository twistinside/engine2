import simd

/// Authoritative ECS state container for one Simulation Runtime session.
///
/// `World` owns per-component sparse stores and simulation resources. Entity
/// objects own lifecycle state and expose typed facades over component rows.
/// Gameplay component systems iterate stores directly; lifecycle systems may
/// iterate the registered entities. Registration is capability-driven:
/// `add(_:from:)` converts an entity's advertised protocols and validated seed
/// values into component rows at the ECS boundary.
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
    var collisionContacts: [CollisionContact] = []
    var collisionSweeps: [CollisionSweep] = []
    var orbitCircularizationCommand: OrbitCircularizationCommand?
    private(set) var selectedEntityID: EntityID?

    private var entitiesByID: [EntityID: Entity] = [:]
    private var reservedEntityIDs: Set<EntityID> = []
    private var nextEntityIndex = 0
    private let orbitCircularizationEstimateEvaluator = OrbitCircularizationEstimateEvaluator()

    /// Entity facades in deterministic identity order for lifecycle collection, UI, and tooling.
    ///
    /// Each entity owns its lifecycle state and projects gameplay component data from World.
    /// Systems that process component data iterate component stores directly.
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
    /// Capability protocols decide which component stores receive rows.
    /// Authored values configure those components; the World supplies neutral
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
        precondition(entity.lifecycleState != .removed, "A removed entity cannot register again.")
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
        addDestructibleComponent(for: entity)
        addDisplayNameComponent(for: entity, from: state)
        addFuelComponent(for: entity, from: state)
        addGravityReceiverComponent(for: entity)
        addGravitySourceComponent(for: entity, from: state)
        addInteractionComponent(for: entity, from: state)
        addMassComponent(for: entity, from: state)
        addMineableComponent(for: entity, from: state)
        addFireableComponent(for: entity)
        addOwnershipComponent(for: entity, from: state)
        addLifetimeComponent(for: entity, from: state)
        addMissileLauncherComponent(for: entity, from: state)
        addOrbitCircularizationComponents(for: entity, from: state)
        addOrbitalRailComponent(for: entity, from: state)
        addOreDepositComponent(for: entity, from: state)
        addPlayerControlComponent(for: entity)
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
    /// Scheduled gameplay calls Entity.markForRemoval(); EntityRemovalSystem owns final collection.
    /// Callers performing immediate destruction must collect identities before this operation compacts stores.
    @discardableResult
    func destroy(_ entity: EntityID) -> Bool {
        guard let facade = entitiesByID.removeValue(forKey: entity) else {
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
        facade.finishRemoval()
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
        let orbitalRail = resolveOrbitalRail(for: entity, from: state)
        precondition(
            state.position == nil || entity is Positionable,
            "Initial state.position requires Positionable conformance"
        )
        guard entity is Positionable else {
            return
        }

        let position = PositionComponent(position: orbitalRail?.position ?? state.position ?? .zero)
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
        let isCargoCarrying = entity is CargoCarrying
        precondition(
            (state.cargoCapacity != nil) == isCargoCarrying &&
                (state.cargoOre != nil) == isCargoCarrying,
            "CargoCarrying requires cargo capacity and ore; other entities must omit both."
        )
        guard let cargoCapacity = state.cargoCapacity, let cargoOre = state.cargoOre else {
            return
        }
        cargoComponents.insert(
            CargoComponent(capacity: cargoCapacity, ore: cargoOre),
            for: entity.id
        )
    }

    private func addCollisionComponents(for entity: Entity, from state: Entity.InitialState) {
        let isCollidable = entity is Collidable
        precondition(
            (state.collisionRadius != nil) == isCollidable &&
                (state.collisionRestitution != nil) == isCollidable,
            "Collidable requires collision radius and restitution; other entities must omit both."
        )
        guard let collisionRadius = state.collisionRadius,
              let collisionRestitution = state.collisionRestitution else {
            return
        }
        guard let position = positionComponents[entity.id]?.position else {
            preconditionFailure("A collidable entity requires its resolved position before collision registration.")
        }
        collisionBodyComponents.insert(
            CollisionBodyComponent(radius: collisionRadius, restitution: collisionRestitution),
            for: entity.id
        )
        previousPositionComponents.insert(PreviousPositionComponent(position: position), for: entity.id)
    }

    private func addDepotServiceComponent(for entity: Entity, from state: Entity.InitialState) {
        let isDepotServicing = entity is DepotServicing
        precondition(
            (state.depotUnloadingRate != nil) == isDepotServicing &&
                (state.depotRefuelingRate != nil) == isDepotServicing,
            "DepotServicing requires unloading and refueling rates; other entities must omit both."
        )
        guard let depotUnloadingRate = state.depotUnloadingRate,
              let depotRefuelingRate = state.depotRefuelingRate else {
            return
        }
        depotServiceComponents.insert(
            DepotServiceComponent(
                unloadingRate: depotUnloadingRate,
                refuelingRate: depotRefuelingRate,
                deliveredOre: 0
            ),
            for: entity.id
        )
    }

    private func addDestructibleComponent(for entity: Entity) {
        guard entity is Destructible else {
            return
        }
        destructibleComponents.insert(DestructibleComponent(), for: entity.id)
    }

    private func addDisplayNameComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.displayName != nil) == (entity is DisplayNamed),
            "InitialState.displayName must be present exactly when the entity conforms to DisplayNamed."
        )
        guard let displayName = state.displayName else {
            return
        }
        displayNameComponents.insert(DisplayNameComponent(value: displayName), for: entity.id)
    }

    private func addFuelComponent(for entity: Entity, from state: Entity.InitialState) {
        let isFueled = entity is Fueled
        precondition(
            (state.fuelCapacity != nil) == isFueled &&
                (state.fuelRemaining != nil) == isFueled,
            "Fueled requires fuel capacity and remaining fuel; other entities must omit both."
        )
        guard let fuelCapacity = state.fuelCapacity, let fuelRemaining = state.fuelRemaining else {
            return
        }
        fuelComponents.insert(
            FuelComponent(capacity: fuelCapacity, remaining: fuelRemaining),
            for: entity.id
        )
    }

    private func addGravityReceiverComponent(for entity: Entity) {
        guard entity is GravityAffected else {
            return
        }
        gravityReceiverComponents.insert(GravityReceiverComponent(), for: entity.id)
    }

    private func addGravitySourceComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.gravitationalParameter != nil) == (entity is GravitySource),
            "InitialState.gravitationalParameter must be present exactly when the entity conforms to GravitySource."
        )
        guard let gravitationalParameter = state.gravitationalParameter else {
            return
        }
        gravitySourceComponents.insert(
            GravitySourceComponent(gravitationalParameter: gravitationalParameter),
            for: entity.id
        )
    }

    private func addInteractionComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.interactionRange != nil) == (entity is Interactable),
            "InitialState.interactionRange must be present exactly when the entity conforms to Interactable."
        )
        guard let interactionRange = state.interactionRange else {
            return
        }
        interactionComponents.insert(InteractionComponent(interactionRange: interactionRange), for: entity.id)
    }

    private func addMassComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.dryMass != nil) == (entity is LiveMass),
            "InitialState.dryMass must be present exactly when the entity conforms to LiveMass."
        )
        guard let dryMass = state.dryMass else {
            return
        }
        massComponents.insert(MassComponent(dryMass: dryMass), for: entity.id)
    }

    private func addMineableComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.miningRate != nil) == (entity is Mineable),
            "InitialState.miningRate must be present exactly when the entity conforms to Mineable."
        )
        guard let miningRate = state.miningRate else {
            return
        }
        mineableComponents.insert(MineableComponent(miningRate: miningRate), for: entity.id)
    }

    private func addFireableComponent(for entity: Entity) {
        guard entity is Fireable else {
            return
        }
        fireableComponents.insert(FireableComponent(), for: entity.id)
    }

    private func addOwnershipComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.ownerEntityID != nil) == (entity is Ownable),
            "InitialState.ownerEntityID must be present exactly when the entity conforms to Ownable."
        )
        guard let ownerEntityID = state.ownerEntityID else {
            return
        }
        ownershipComponents.insert(OwnershipComponent(ownerEntityID: ownerEntityID), for: entity.id)
    }

    private func addLifetimeComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.lifetime != nil) == (entity is Expirable),
            "InitialState.lifetime must be present exactly when the entity conforms to Expirable."
        )
        guard let lifetime = state.lifetime else {
            return
        }
        lifetimeComponents.insert(LifetimeComponent(remainingLifetime: lifetime), for: entity.id)
    }

    private func addMissileLauncherComponent(for entity: Entity, from state: Entity.InitialState) {
        let isMissileLaunching = entity is MissileLaunching
        precondition(
            (state.missileSpeed != nil) == isMissileLaunching &&
                (state.missileLifetime != nil) == isMissileLaunching &&
                (state.missileRadius != nil) == isMissileLaunching,
            "MissileLaunching requires missile speed, lifetime, and radius; other entities must omit all three."
        )
        guard let missileSpeed = state.missileSpeed,
              let missileLifetime = state.missileLifetime,
              let missileRadius = state.missileRadius else {
            return
        }
        missileLauncherComponents.insert(
            MissileLauncherComponent(
                speed: missileSpeed,
                lifetime: missileLifetime,
                radius: missileRadius
            ),
            for: entity.id
        )
    }

    private func addOrbitCircularizationComponents(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.orbitPrimaryID != nil) == (entity is OrbitCircularizable),
            "InitialState.orbitPrimaryID must be present exactly when the entity conforms to OrbitCircularizable."
        )
        guard let orbitPrimaryID = state.orbitPrimaryID else {
            return
        }
        orbitPrimaryComponents.insert(OrbitPrimaryComponent(primaryEntityID: orbitPrimaryID), for: entity.id)
        orbitCircularizationAutopilotComponents.insert(.idle, for: entity.id)
    }

    private func addOrbitalRailComponent(for entity: Entity, from state: Entity.InitialState) {
        guard let orbitalRail = resolveOrbitalRail(for: entity, from: state) else {
            return
        }
        orbitalRailComponents.insert(orbitalRail.component, for: entity.id)
    }

    private func resolveOrbitalRail(
        for entity: Entity,
        from state: Entity.InitialState
    ) -> (component: OrbitalRailComponent, position: SIMD3<Double>)? {
        let isOrbiting = entity is Orbiting
        precondition(
            (state.orbitalPrimaryID != nil) == isOrbiting &&
                (state.orbitalRadius != nil) == isOrbiting &&
                (state.orbitalAngularSpeed != nil) == isOrbiting &&
                (state.orbitalPhase != nil) == isOrbiting,
            "Orbiting requires primary identity, radius, angular speed, and phase; other entities must omit all four."
        )
        guard let orbitalPrimaryID = state.orbitalPrimaryID,
              let orbitalRadius = state.orbitalRadius,
              let orbitalAngularSpeed = state.orbitalAngularSpeed,
              let orbitalPhase = state.orbitalPhase else {
            return nil
        }
        precondition(!(entity is Movable), "An orbital rail cannot also use dynamically integrated motion.")
        precondition(
            state.position == nil &&
                state.velocity == nil &&
                state.accelerationIntent == nil &&
                state.impulse == nil,
            "An orbital rail derives its translational state; explicit position and motion seeds are not allowed."
        )
        precondition(
            orbitalPrimaryID != entity.id,
            "An orbital rail cannot use its own entity as its primary."
        )
        guard entitiesByID[orbitalPrimaryID] != nil,
              let primaryPosition = positionComponents[orbitalPrimaryID]?.position else {
            preconditionFailure("An orbital rail requires a registered primary with the complete supplied identity.")
        }
        precondition(primaryPosition.isFinite, "An orbital rail primary position must be finite.")

        var component = OrbitalRailComponent(
            primaryEntityID: orbitalPrimaryID,
            radius: orbitalRadius,
            angularSpeed: orbitalAngularSpeed,
            phase: orbitalPhase,
            elapsedTime: 0,
            velocity: .zero
        )
        let initialOrbit = component.state(relativeTo: primaryPosition)
        precondition(
            initialOrbit.position.isFinite && initialOrbit.velocity.isFinite,
            "An orbital rail must resolve a finite initial position and velocity."
        )
        component.velocity = initialOrbit.velocity
        return (component, initialOrbit.position)
    }

    private func addOreDepositComponent(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.remainingOre != nil) == (entity is OreContaining),
            "InitialState.remainingOre must be present exactly when the entity conforms to OreContaining."
        )
        guard let remainingOre = state.remainingOre else {
            return
        }
        oreDepositComponents.insert(OreDepositComponent(remainingOre: remainingOre), for: entity.id)
    }

    private func addPlayerControlComponent(for entity: Entity) {
        guard entity is PlayerControlled else {
            return
        }
        playerControlComponents.insert(
            PlayerControlComponent(translation: .zero, interactionState: .inactive, isFireRequested: false),
            for: entity.id
        )
    }

    private func addPropulsionComponent(for entity: Entity, from state: Entity.InitialState) {
        let isPropelled = entity is Propelled
        precondition(
            (state.maximumThrust != nil) == isPropelled &&
                (state.exhaustVelocity != nil) == isPropelled,
            "Propelled requires maximum thrust and exhaust velocity; other entities must omit both."
        )
        guard let maximumThrust = state.maximumThrust, let exhaustVelocity = state.exhaustVelocity else {
            return
        }
        propulsionComponents.insert(
            PropulsionComponent(maximumThrust: maximumThrust, exhaustVelocity: exhaustVelocity),
            for: entity.id
        )
    }

    private func addRenderableComponent(for entity: Entity, from state: Entity.InitialState) {
        let isRenderable = entity is Renderable
        precondition(
            (state.meshID != nil) == isRenderable &&
                (state.materialID != nil) == isRenderable,
            "Renderable requires mesh and material identities; other entities must omit both."
        )
        guard let meshID = state.meshID, let materialID = state.materialID else {
            return
        }
        renderableComponents.insert(
            RenderableComponent(meshID: meshID, materialID: materialID),
            for: entity.id
        )
    }

    private func addSelectionComponents(for entity: Entity, from state: Entity.InitialState) {
        let isSelectable = entity is Selectable
        precondition(
            state.selectionState == nil || isSelectable,
            "Initial state.selectionState requires Selectable conformance"
        )
        precondition(
            (state.selectionRadius != nil) == isSelectable,
            "InitialState.selectionRadius must be present exactly when the entity conforms to Selectable."
        )
        guard let selectionRadius = state.selectionRadius else {
            return
        }

        let selectionState: SelectableComponent.SelectionState = selectedEntityID == entity.id
            ? .selected
            : state.selectionState ?? .unselected
        let selectable = SelectableComponent(selectionState: selectionState)
        selectableComponents.insert(selectable, for: entity.id)
        selectionBoundsComponents.insert(SelectionBoundsComponent(radius: selectionRadius), for: entity.id)
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
        entity.activateAfterRegistration()
    }

    /// Reserves a fresh identity without reusing a destroyed entity's index.
    func reserveEntityID() -> EntityID {
        let entityID = EntityID(index: nextEntityIndex, generation: 0)
        nextEntityIndex += 1
        reservedEntityIDs.insert(entityID)
        return entityID
    }
}
