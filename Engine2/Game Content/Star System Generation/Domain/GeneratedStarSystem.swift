import Foundation

/// Fully resolved, immutable result of one deterministic construction-time generation.
///
/// The value is safe to persist and reuse across runtime reconstruction. Runtime
/// or ECS integration must consume this resolved value rather than rerunning the
/// generator from inside `PWorldBuilder`.
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
    /// present-day facts, then checks identities, ancestry, orbital stability,
    /// satellite bounds, and both conserved disk mass budgets.
    func validate() throws(StarSystemGenerationError) {
        try GeneratedStarSystemValidator(system: self).validate()
    }
}
