/// Exhaustive Game Content identity for packaged mesh assets.
///
/// The Simulation and Render Runtimes carry and resolve these values, but Game
/// Content owns the vocabulary because it defines the entities and meshes that
/// exist in this game.
nonisolated enum MeshID: Codable, Hashable, Sendable {
    case ball
}
