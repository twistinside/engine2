/// Represents the selected body's gravity metric at one displayed epoch.
nonisolated enum GravitySystemSelectedGravityState: Equatable, Sendable {
    /// No generated body is selected for evaluation.
    case unavailable

    /// The gravity field produced one finite acceleration magnitude.
    case available(metersPerSecondSquared: Double)

    /// The gravity field rejected the selected position.
    case failed(PlanarGravityFieldError)
}
