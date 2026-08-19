/// Stable identity for one generated system presented by the explorer.
///
/// Changing either component reconstructs Dynamics workspace presentation
/// state, including playback, zoom, and transfer selection.
nonisolated struct StarSystemExplorerSystemIdentity: Hashable, Sendable {
    let modelVersion: StarSystemGenerationModelVersion
    let seed: StarSystemSeed

    init(system: GeneratedStarSystem) {
        modelVersion = system.modelVersion
        seed = system.seed
    }
}
