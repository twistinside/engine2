/// Represents whether the explorer can project one generated star system into deterministic gravity rails.
enum GravitySystemProjectionState {
    /// Projection construction has not produced a result.
    case unavailable

    /// The source system produced one validated gravity-system projection.
    case ready(GeneratedGravitySystem)

    /// Gravity-system generation rejected the source or projected value.
    case failed(GravitySystemGenerationError)
}
