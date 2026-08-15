/// Conserved post-disk encounter outcomes and bounded-work counts.
///
/// Removed compositions remain separate so the generated system ledger can
/// close every solid and hydrogen-helium component without treating losses as
/// surviving planets.
nonisolated struct PlanetaryArchitectureResolution: Sendable {
    static let empty = PlanetaryArchitectureResolution(
        collisionMergerCount: 0,
        scatteringCount: 0,
        ejectedBodyCount: 0,
        ejectedProgenitorCount: 0,
        starAccretedBodyCount: 0,
        starAccretedProgenitorCount: 0,
        ejectedComposition: .zero,
        starAccretedComposition: .zero,
        collisionDebrisComposition: .zero
    )

    var collisionMergerCount: Int
    var scatteringCount: Int
    var ejectedBodyCount: Int
    var ejectedProgenitorCount: Int
    var starAccretedBodyCount: Int
    var starAccretedProgenitorCount: Int
    var ejectedComposition: CelestialMassComposition
    var starAccretedComposition: CelestialMassComposition
    var collisionDebrisComposition: CelestialMassComposition

    mutating func recordCollision(debris: CelestialMassComposition) {
        collisionMergerCount += 1
        collisionDebrisComposition = collisionDebrisComposition.adding(debris)
    }

    mutating func recordScattering() {
        scatteringCount += 1
    }

    mutating func recordEjection(_ embryo: FormationEmbryo) {
        ejectedBodyCount += 1
        ejectedProgenitorCount += embryo.progenitorCount
        ejectedComposition = ejectedComposition.adding(embryo.composition)
    }

    mutating func recordStellarAccretion(_ embryo: FormationEmbryo) {
        starAccretedBodyCount += 1
        starAccretedProgenitorCount += embryo.progenitorCount
        starAccretedComposition = starAccretedComposition.adding(embryo.composition)
    }
}
