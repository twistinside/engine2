import simd

/// Evaluates one validated planar ephemeris into detached absolute states.
///
/// The evaluator composes each rail with its complete parent chain and returns
/// states in the definition's stable identity order. Its cached lookup contains
/// immutable definitions only; each evaluation owns independent state storage.
nonisolated struct PlanarEphemerisEvaluator: Sendable {
    let definition: PlanarEphemerisDefinition

    private let kernel: PlanarKeplerPropagationKernel
    private let bodiesByID: [CelestialBodyID: PlanarEphemerisBodyDefinition]

    init(
        definition: PlanarEphemerisDefinition,
        kernel: PlanarKeplerPropagationKernel = PlanarKeplerPropagationKernel()
    ) {
        self.definition = definition
        self.kernel = kernel
        self.bodiesByID = Dictionary(
            uniqueKeysWithValues: definition.bodies.map { ($0.id, $0) }
        )
    }

    /// Returns every absolute state in stable body-identity order.
    func states(
        at epoch: CelestialEpoch
    ) throws(PlanarEphemerisError) -> [PlanarOrbitalBodyState] {
        var statesByID: [CelestialBodyID: PlanarStateVector] = [:]
        var bodyStates: [PlanarOrbitalBodyState] = []
        bodyStates.reserveCapacity(definition.bodies.count)
        for body in definition.bodies {
            bodyStates.append(
                PlanarOrbitalBodyState(
                    id: body.id,
                    state: try evaluatedState(
                        for: body,
                        at: epoch,
                        statesByID: &statesByID
                    )
                )
            )
        }
        return bodyStates
    }

    private func evaluatedState(
        for body: PlanarEphemerisBodyDefinition,
        at epoch: CelestialEpoch,
        statesByID: inout [CelestialBodyID: PlanarStateVector]
    ) throws(PlanarEphemerisError) -> PlanarStateVector {
        if let state = statesByID[body.id] {
            return state
        }

        let state: PlanarStateVector
        switch body {
        case let .root(_, rootState):
            state = rootState
        case let .parentRelativeRail(id, parentID, rail):
            guard let parent = bodiesByID[parentID] else {
                preconditionFailure("A validated ephemeris must contain every referenced parent body.")
            }
            let parentState = try evaluatedState(
                for: parent,
                at: epoch,
                statesByID: &statesByID
            )
            let relativeState = kernel.state(on: rail, at: epoch)
            let absolutePosition = parentState.position.meters
                + relativeState.position.meters
            let absoluteVelocity = parentState.velocity.metersPerSecond
                + relativeState.velocity.metersPerSecond
            guard absolutePosition.isFinite, absoluteVelocity.isFinite else {
                throw .nonfiniteState(id)
            }
            state = PlanarStateVector(
                position: PlanarPosition(meters: absolutePosition),
                velocity: PlanarVelocity(metersPerSecond: absoluteVelocity)
            )
        }
        statesByID[body.id] = state
        return state
    }
}
