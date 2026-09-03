/// Semantic interaction command assigned to one player-controllable entity.
///
/// Simulation derives this state from context-free Input Runtime intent after
/// resolving authoritative selection. Additional interaction modes can extend
/// this vocabulary without changing the physical-input boundary.
nonisolated enum PlayerInteractionState: Codable, Equatable, Sendable {
    case inactive
    case active
}
