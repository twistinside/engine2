/// Failures that prevent finite inverse-square gravity evaluation.
nonisolated enum PlanarGravityFieldError: Error, Equatable, Sendable {
    /// The supplied ephemeris snapshot belongs to another generated system.
    case snapshotSystemMismatch

    /// The queried position is at or inside the generated star's radius.
    case contactWithStar

    /// The queried position is at or inside one generated body's radius.
    case contactWithBody(GeneratedBodyID)

    /// The source sum produced a nonfinite acceleration vector.
    case nonfiniteAcceleration
}
