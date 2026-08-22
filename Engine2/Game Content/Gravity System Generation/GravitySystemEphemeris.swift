/// Evaluates absolute generated-body states from one validated rail hierarchy.
///
/// Planet states are relative to the star at the origin. Moon states compose
/// their parent planet's absolute state with the moon's parent-relative rail.
/// Snapshots preserve the system's stable body-identity order and retain the
/// system and epoch that produced their states.
nonisolated struct GravitySystemEphemeris: Sendable {
    let system: GeneratedGravitySystem

    private let kernel: PlanarKeplerPropagationKernel
    private let bodiesByID: [GeneratedBodyID: GravityRailBody]

    init(
        system: GeneratedGravitySystem,
        kernel: PlanarKeplerPropagationKernel = PlanarKeplerPropagationKernel()
    ) throws(GravitySystemGenerationError) {
        try system.validate()
        self.system = system
        self.kernel = kernel
        self.bodiesByID = Dictionary(
            uniqueKeysWithValues: system.bodies.map { ($0.id, $0) }
        )
    }

    /// Returns the generated body for one stable identity.
    func body(for bodyID: GeneratedBodyID) -> GravityRailBody? {
        bodiesByID[bodyID]
    }

    /// Returns one body's absolute state, or `nil` when the identity is absent.
    func state(
        for bodyID: GeneratedBodyID,
        at epoch: CelestialEpoch
    ) -> PlanarStateVector? {
        guard let body = bodiesByID[bodyID] else {
            return nil
        }
        var statesByID: [GeneratedBodyID: PlanarStateVector] = [:]
        return state(for: body, at: epoch, cachingIn: &statesByID)
    }

    /// Evaluates one complete, provenance-preserving system snapshot.
    func snapshot(at epoch: CelestialEpoch) -> GravitySystemEphemerisSnapshot {
        GravitySystemEphemerisSnapshot(evaluating: self, at: epoch)
    }

    /// Evaluates every generated body in stable identity order.
    ///
    /// ``GravitySystemEphemerisSnapshot`` owns this array at the public
    /// consumption boundary so callers retain its source-system provenance.
    func evaluatedBodyStates(at epoch: CelestialEpoch) -> [GravityBodyState] {
        var statesByID: [GeneratedBodyID: PlanarStateVector] = [:]
        return system.bodies.map { body in
            let state = state(
                for: body,
                at: epoch,
                cachingIn: &statesByID
            )
            return GravityBodyState(body: body, state: state)
        }
    }

    private func state(
        for body: GravityRailBody,
        at epoch: CelestialEpoch,
        cachingIn statesByID: inout [GeneratedBodyID: PlanarStateVector]
    ) -> PlanarStateVector {
        if let state = statesByID[body.id] {
            return state
        }
        let relativeState = kernel.state(on: body.rail, at: epoch)
        let absoluteState: PlanarStateVector
        if let parentID = body.parentID {
            let parent = validatedBody(for: parentID)
            let parentState = state(
                for: parent,
                at: epoch,
                cachingIn: &statesByID
            )
            absoluteState = relativeState.composed(withParent: parentState)
        } else {
            absoluteState = relativeState
        }
        statesByID[body.id] = absoluteState
        return absoluteState
    }

    private func validatedBody(for bodyID: GeneratedBodyID) -> GravityRailBody {
        guard let body = bodiesByID[bodyID] else {
            preconditionFailure(
                "A validated gravity system must contain every referenced parent body."
            )
        }
        return body
    }
}
