/// Failures that prevent finite inverse-square gravity evaluation.
nonisolated enum PlanarGravityFieldError: Error, Equatable, Sendable {
    case contactWithStar
    case contactWithBody(GeneratedBodyID)
    case nonfiniteAcceleration
}
