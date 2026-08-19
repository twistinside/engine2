/// Represents whether the explorer can project one generated star system into deterministic gravity rails.
enum GravitySystemProjectionState {
    case ready(GeneratedGravitySystem)
    case failed(String)
}
