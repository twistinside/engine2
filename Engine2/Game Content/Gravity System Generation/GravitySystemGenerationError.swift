/// Closed failure domain for gravity-system projection and validation.
nonisolated enum GravitySystemGenerationError: Error, Equatable, Sendable {
    case unsupportedDynamicsModel(CelestialDynamicsModelVersion)
    case invalidSourceSystem
    case invalidStar
    case bodiesNotOrdered
    case duplicateBodyID(GeneratedBodyID)
    case invalidBody(GeneratedBodyID)
    case missingParent(body: GeneratedBodyID, parent: GeneratedBodyID)
    /// The optional primary identity is `nil` when the rail intersects the generated star.
    case periapsisIntersectsPrimary(body: GeneratedBodyID, primaryBodyID: GeneratedBodyID?)
    case inconsistentPhase(GeneratedBodyID)
    case inconsistentGravitationalParameter(GeneratedBodyID)
}
