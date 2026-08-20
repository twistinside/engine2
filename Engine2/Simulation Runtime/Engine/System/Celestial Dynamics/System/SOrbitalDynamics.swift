/// Advances authoritative planar orbital state through shared celestial mechanics.
///
/// The system is an ECS adapter. It reads stable body identity, physical facts,
/// motion authority, and gravity roles from `World`; evaluates prescribed rails
/// at exact epochs through the World-selected model; invokes
/// ``PlanarOrbitalDynamicsStepper``; then commits every resulting
/// ``COrbitalMotion`` row and ``CelestialTimeline`` together. The numerical
/// mechanics own no ECS or Game Content dependency.
struct SOrbitalDynamics: PSystem {
    let modelVersion: PlanarOrbitalDynamicsModelVersion
    let durationSeconds: Double

    private let stepper: PlanarOrbitalDynamicsStepper

    init(
        modelVersion: PlanarOrbitalDynamicsModelVersion,
        durationSeconds: Double
    ) {
        precondition(
            durationSeconds.isFinite && durationSeconds > 0,
            "Orbital dynamics requires a positive finite step duration."
        )
        self.modelVersion = modelVersion
        self.durationSeconds = durationSeconds
        self.stepper = PlanarOrbitalDynamicsStepper(modelVersion: modelVersion)
    }

    mutating func update(world: inout World, deltaTime _: Float) {
        do {
            try advance(world: &world)
        } catch {
            preconditionFailure(
                "The invariant orbital-dynamics schedule rejected its World state: \(error)"
            )
        }
    }

    /// Calculates and commits one complete celestial step.
    ///
    /// Focused tests and future coordinators can use the typed refusal before
    /// the scheduler grows a collision-resolution and event-publication lane.
    func advance(
        world: inout World
    ) throws(OrbitalDynamicsSystemError) {
        try validateComponentTopology(in: world)
        guard !world.celestialBodyIndex.isEmpty else {
            return
        }

        let currentEpoch = world.celestialTimeline.epoch
        let nextEpoch = try nextEpoch(after: currentEpoch)
        let evaluator = try makeEphemerisEvaluator(from: world)
        let currentPrescribedStates = try evaluate(
            evaluator,
            at: currentEpoch
        )
        let nextPrescribedStates = try evaluate(
            evaluator,
            at: nextEpoch
        )
        let bodies = try makeOrbitalBodies(
            from: world,
            currentPrescribedStates: currentPrescribedStates,
            nextPrescribedStates: nextPrescribedStates
        )
        let result = try step(bodies)
        try validate(result, against: world.celestialBodyIndex)
        commit(
            result,
            at: nextEpoch,
            to: &world
        )
    }

    private func validateComponentTopology(
        in world: World
    ) throws(OrbitalDynamicsSystemError) {
        let expectedCount = world.celestialBodyIndex.count
        guard world.celestialIdentityComponents.dense.count == expectedCount,
              world.massiveBodyComponents.dense.count == expectedCount,
              world.orbitalMotionComponents.dense.count == expectedCount,
              world.gravityParticipationComponents.dense.count == expectedCount else {
            throw .componentCardinalityMismatch
        }

        for bodyID in world.celestialBodyIndex.orderedBodyIDs {
            guard let entityID = world.celestialBodyIndex[bodyID] else {
                throw .missingIndexedEntity(bodyID)
            }
            guard let identity = world.celestialIdentityComponents[entityID] else {
                throw .missingCelestialIdentity(bodyID)
            }
            guard identity.bodyID == bodyID else {
                throw .celestialIdentityMismatch(bodyID)
            }
            guard world.massiveBodyComponents[entityID] != nil else {
                throw .missingMassiveBody(bodyID)
            }
            guard world.orbitalMotionComponents[entityID] != nil else {
                throw .missingOrbitalMotion(bodyID)
            }
            guard world.gravityParticipationComponents[entityID] != nil else {
                throw .missingGravityParticipation(bodyID)
            }
        }
    }

    private func nextEpoch(
        after currentEpoch: CelestialEpoch
    ) throws(OrbitalDynamicsSystemError) -> CelestialEpoch {
        let nextSeconds = currentEpoch.secondsSinceReferenceEpoch
            + durationSeconds
        guard nextSeconds.isFinite,
              nextSeconds > currentEpoch.secondsSinceReferenceEpoch else {
            throw .unrepresentableNextEpoch
        }
        return CelestialEpoch(secondsSinceReferenceEpoch: nextSeconds)
    }

    private func makeEphemerisEvaluator(
        from world: World
    ) throws(OrbitalDynamicsSystemError) -> PlanarEphemerisEvaluator? {
        var definitions: [PlanarEphemerisBodyDefinition] = []
        for bodyID in world.celestialBodyIndex.orderedBodyIDs {
            guard let entityID = world.celestialBodyIndex[bodyID],
                  let motion = world.orbitalMotionComponents[entityID] else {
                throw .missingOrbitalMotion(bodyID)
            }
            switch motion.authority {
            case .integrated:
                continue
            case .ephemerisRoot:
                definitions.append(
                    .root(id: bodyID, state: motion.orbitalState)
                )
            case let .keplerianRail(parentID, rail):
                definitions.append(
                    .parentRelativeRail(
                        id: bodyID,
                        parentID: parentID,
                        rail: rail
                    )
                )
            }
        }

        guard !definitions.isEmpty else {
            return nil
        }
        guard let configuration = world.celestialEphemerisConfiguration else {
            throw .missingEphemerisConfiguration
        }

        do {
            let definition = try PlanarEphemerisDefinition(bodies: definitions)
            switch configuration.modelVersion {
            case .planarKeplerV1:
                return PlanarEphemerisEvaluator(definition: definition)
            }
        } catch {
            throw .ephemeris(error)
        }
    }

    private func evaluate(
        _ evaluator: PlanarEphemerisEvaluator?,
        at epoch: CelestialEpoch
    ) throws(OrbitalDynamicsSystemError) -> [CelestialBodyID: PlanarStateVector] {
        guard let evaluator else {
            return [:]
        }
        do {
            let states = try evaluator.states(at: epoch)
            return Dictionary(
                uniqueKeysWithValues: states.map { ($0.id, $0.state) }
            )
        } catch {
            throw .ephemeris(error)
        }
    }

    private func makeOrbitalBodies(
        from world: World,
        currentPrescribedStates: [CelestialBodyID: PlanarStateVector],
        nextPrescribedStates: [CelestialBodyID: PlanarStateVector]
    ) throws(OrbitalDynamicsSystemError) -> [PlanarOrbitalBody] {
        var bodies: [PlanarOrbitalBody] = []
        bodies.reserveCapacity(world.celestialBodyIndex.count)
        for bodyID in world.celestialBodyIndex.orderedBodyIDs {
            guard let entityID = world.celestialBodyIndex[bodyID],
                  let massiveBody = world.massiveBodyComponents[entityID],
                  let motion = world.orbitalMotionComponents[entityID],
                  let gravity = world.gravityParticipationComponents[entityID] else {
                throw .componentCardinalityMismatch
            }
            let input = try makeOrbitalBody(
                bodyID: bodyID,
                massiveBody: massiveBody,
                motion: motion,
                gravity: gravity,
                currentPrescribedState: currentPrescribedStates[bodyID],
                nextPrescribedState: nextPrescribedStates[bodyID]
            )
            bodies.append(input)
        }
        return bodies
    }

    private func makeOrbitalBody(
        bodyID: CelestialBodyID,
        massiveBody: CMassiveBody,
        motion: COrbitalMotion,
        gravity: CGravityParticipation,
        currentPrescribedState: PlanarStateVector?,
        nextPrescribedState: PlanarStateVector?
    ) throws(OrbitalDynamicsSystemError) -> PlanarOrbitalBody {
        let initialState: PlanarStateVector
        let propagation: PlanarOrbitalPropagation
        switch motion.authority {
        case .integrated:
            initialState = motion.orbitalState
            propagation = .integrated
        case .ephemerisRoot, .keplerianRail:
            guard gravity.participation == .sourceOnly
                    || gravity.participation == .none else {
                throw .invalidPrescribedGravityParticipation(bodyID)
            }
            guard let currentPrescribedState,
                  let nextPrescribedState else {
                throw .componentCardinalityMismatch
            }
            guard motion.orbitalState == currentPrescribedState else {
                throw .prescribedStateMismatch(bodyID)
            }
            initialState = currentPrescribedState
            propagation = .prescribed(endState: nextPrescribedState)
        }

        return PlanarOrbitalBody(
            id: bodyID,
            massKilograms: massiveBody.mass.kilograms,
            radiusMeters: massiveBody.physicalRadius.meters,
            initialState: initialState,
            propagation: propagation,
            gravityParticipation: gravity.participation
        )
    }

    private func step(
        _ bodies: [PlanarOrbitalBody]
    ) throws(OrbitalDynamicsSystemError) -> PlanarOrbitalDynamicsStepResult {
        do {
            return try stepper.step(
                bodies: bodies,
                durationSeconds: durationSeconds
            )
        } catch {
            throw .mechanics(error)
        }
    }

    private func validate(
        _ result: PlanarOrbitalDynamicsStepResult,
        against index: CelestialBodyIndex
    ) throws(OrbitalDynamicsSystemError) {
        guard result.modelVersion == modelVersion else {
            throw .resultModelVersionMismatch
        }
        guard result.bodyStates.map(\.id) == index.orderedBodyIDs else {
            throw .resultBodyOrderMismatch
        }
    }

    private func commit(
        _ result: PlanarOrbitalDynamicsStepResult,
        at epoch: CelestialEpoch,
        to world: inout World
    ) {
        for bodyState in result.bodyStates {
            guard let entityID = world.celestialBodyIndex[bodyState.id] else {
                preconditionFailure(
                    "Validated orbital results must retain every indexed celestial body."
                )
            }
            let updated = world.orbitalMotionComponents.update(for: entityID) {
                $0.orbitalState = bodyState.state
            }
            precondition(
                updated,
                "Validated orbital results must update every orbital component."
            )
        }
        world.celestialTimeline.commit(
            epoch: epoch,
            predictionBasisRevision: world.celestialTimeline.predictionBasisRevision
        )
    }
}
