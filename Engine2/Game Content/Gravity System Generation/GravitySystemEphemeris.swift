/// Evaluates absolute generated-body states from one validated rail hierarchy.
///
/// Planet states are relative to the star at the origin. Moon states compose
/// their parent planet's absolute state with the moon's parent-relative rail.
/// Returned arrays preserve the system's stable body-identity order.
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
        let relativeState = kernel.state(on: body.rail, at: epoch)
        guard let parentID = body.parentID else {
            return relativeState
        }
        guard let parentState = state(for: parentID, at: epoch) else {
            return nil
        }
        return relativeState.composed(withParent: parentState)
    }

    /// Returns every generated body and absolute state in stable identity order.
    func states(at epoch: CelestialEpoch) -> [GravityBodyState] {
        system.bodies.compactMap { body in
            guard let state = state(for: body.id, at: epoch) else {
                return nil
            }
            return GravityBodyState(body: body, state: state)
        }
    }
}
