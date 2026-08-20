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
    var celestialIdentityComponents = ComponentStore<CCelestialIdentity>()
    var gravityParticipationComponents = ComponentStore<CGravityParticipation>()
    var massiveBodyComponents = ComponentStore<CMassiveBody>()
    var motionComponents = ComponentStore<CMotion>()
    var orbitalMotionComponents = ComponentStore<COrbitalMotion>()
    var positionComponents = ComponentStore<CPosition>()
    var renderableComponents = ComponentStore<CRenderable>()
    var rotationComponents = ComponentStore<CRotation>()
    var scaleComponents = ComponentStore<CScale>()
    var selectableComponents = ComponentStore<CSelectable>()
    var stellarEmissionComponents = ComponentStore<CStellarEmission>()

    // MARK: Resources
    var camera = Camera.standard
    var celestialBodyIndex = CelestialBodyIndex()
    var celestialEphemerisConfiguration: CelestialEphemerisConfiguration?
    var celestialTimeline = CelestialTimeline(
        epoch: .zero,
        predictionBasisRevision: .zero
    )
    var input = InputState()
    var inputHistory = InputHistory(maximumEntryCount: 60)

    private var nextEntityIndex = 0

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
                position: positionComponents[entity]?.position,
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
        return entity.id
    }

    /// Creates the authoritative celestial rows for one typed entity facade.
    ///
    /// Celestial construction uses a focused aggregate because double-precision
    /// orbital state, physical mass, and stellar emission are not extensions of
    /// the render-scale transform seed. Stable celestial identity is registered
    /// once before systems begin iterating the World-owned index.
    @discardableResult
    func addCelestialBody(
        _ entity: Entity,
        from state: CelestialBodyInitialState
    ) -> EntityID {
        precondition(
            entity is PCelestialBody,
            "Celestial body initial state requires PCelestialBody conformance."
        )
        precondition(
            (entity is PStellarEmitter) == (state.stellarEmission != nil),
            "PStellarEmitter conformance and stellar emission must occur together."
        )

        do {
            try celestialBodyIndex.register(
                state.identity.bodyID,
                for: entity.id
            )
        } catch {
            preconditionFailure(error.message)
        }

        celestialIdentityComponents.insert(state.identity, for: entity.id)
        massiveBodyComponents.insert(state.massiveBody, for: entity.id)
        orbitalMotionComponents.insert(state.orbitalMotion, for: entity.id)
        gravityParticipationComponents.insert(
            state.gravityParticipation,
            for: entity.id
        )
        if let stellarEmission = state.stellarEmission {
            stellarEmissionComponents.insert(stellarEmission, for: entity.id)
        }
        return entity.id
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

        let selectable = CSelectable(selectionState: state.selectionState ?? .unselected)
        selectableComponents.insert(selectable, for: entity.id)
    }

    func reserveEntityID() -> EntityID {
        // Until entity destruction exists, each reservation consumes a fresh
        // index so entity identities never alias a previous live row.
        let entityID = EntityID(index: nextEntityIndex, generation: 0)
        nextEntityIndex += 1
        return entityID
    }
}
