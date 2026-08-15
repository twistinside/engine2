/// Material and ancestry removed from retained primary bodies by post-disk encounters.
///
/// Ejected and star-accreted compositions leave the generated planetary architecture.
/// Collision debris retains material in the system without assigning it to one resolved
/// body. Counts preserve the bounded event history needed to validate embryo ancestry.
nonisolated struct StarSystemDynamicalLossLedger: Codable, Equatable, Sendable {
    static let zero = StarSystemDynamicalLossLedger(
        ejectedComposition: .zero,
        starAccretedComposition: .zero,
        collisionDebrisComposition: .zero,
        scatteringCount: 0,
        ejectedBodyCount: 0,
        ejectedProgenitorCount: 0,
        starAccretedBodyCount: 0,
        starAccretedProgenitorCount: 0
    )

    let ejectedComposition: CelestialMassComposition
    let starAccretedComposition: CelestialMassComposition
    let collisionDebrisComposition: CelestialMassComposition
    let scatteringCount: Int
    let ejectedBodyCount: Int
    let ejectedProgenitorCount: Int
    let starAccretedBodyCount: Int
    let starAccretedProgenitorCount: Int
}
