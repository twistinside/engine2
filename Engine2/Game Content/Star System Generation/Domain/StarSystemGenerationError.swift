/// Closed failure domain for generation and resolved-system validation.
nonisolated enum StarSystemGenerationError: Error, Equatable, Sendable {
    case noFundedEmbryos
    case inconsistentModelVersion
    case invalidPolicy
    case invalidStar
    case invalidDisk
    case invalidFormationLedger
    case duplicateBodyID(GeneratedBodyID)
    case planetsNotOrdered
    case invalidPlanet(GeneratedBodyID)
    case invalidMoon(GeneratedBodyID)
    case inconsistentDerivedBody(GeneratedBodyID)
    case unstablePlanetPair(inner: GeneratedBodyID, outer: GeneratedBodyID)
    case unstableMoonPair(parent: GeneratedBodyID, inner: GeneratedBodyID, outer: GeneratedBodyID)
    case massConservationFailure(StarSystemMassBudget)
}
