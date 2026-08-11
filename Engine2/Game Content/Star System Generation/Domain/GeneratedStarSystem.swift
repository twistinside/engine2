import Foundation

/// Resolved, immutable result of one deterministic construction-time generation.
///
/// Generator-produced values have passed validation and can be persisted.
/// Decoding does not establish trust; callers must invoke `validate()` before
/// reusing decoded bytes. Runtime or ECS integration must consume this resolved
/// value rather than rerunning the generator from inside `PWorldBuilder`.
/// Selected significant planets retain detailed facts; every omitted survivor
/// remains aggregate ledger provenance.
nonisolated struct GeneratedStarSystem: Codable, Equatable, Sendable {
    let seed: StarSystemSeed
    let modelVersion: StarSystemGenerationModelVersion
    let policy: StarSystemGenerationPolicy
    let star: GeneratedStar
    let protoplanetaryDisk: GeneratedProtoplanetaryDisk
    let formationLedger: StarSystemFormationLedger
    let planets: [GeneratedPlanet]

    /// Validates persistence input and the generator's complete output invariants.
    ///
    /// Validation admits only the canonical policy, replays seed-derived and
    /// present-day facts, then checks identities, retained and residual ancestry,
    /// orbital stability, satellite bounds, and both conserved disk mass budgets.
    func validate() throws(StarSystemGenerationError) {
        try GeneratedStarSystemValidator(system: self).validate()
    }
}
