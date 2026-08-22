/// One complete, epoch-qualified evaluation of a generated gravity system.
///
/// The snapshot retains the exact validated system that produced its body
/// states. Consumers can therefore reject values from another system instead
/// of combining plausible coordinates with the wrong gravity sources.
nonisolated struct GravitySystemEphemerisSnapshot: Equatable, Sendable {
    let system: GeneratedGravitySystem
    let epoch: CelestialEpoch
    let bodyStates: [GravityBodyState]

    private let bodyStatesByID: [GeneratedBodyID: PlanarStateVector]

    var seed: StarSystemSeed {
        system.seed
    }

    var modelVersion: CelestialDynamicsModelVersion {
        system.modelVersion
    }

    /// Evaluates every body in the ephemeris's stable identity order.
    init(
        evaluating ephemeris: GravitySystemEphemeris,
        at epoch: CelestialEpoch
    ) {
        system = ephemeris.system
        self.epoch = epoch

        let bodyStates = ephemeris.evaluatedBodyStates(at: epoch)
        self.bodyStates = bodyStates
        self.bodyStatesByID = Dictionary(
            uniqueKeysWithValues: bodyStates.map { ($0.body.id, $0.state) }
        )
    }

    /// Returns one absolute state without scanning the ordered body array.
    func state(for bodyID: GeneratedBodyID) -> PlanarStateVector? {
        bodyStatesByID[bodyID]
    }
}
