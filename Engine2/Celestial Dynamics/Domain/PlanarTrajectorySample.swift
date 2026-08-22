/// One epoch-qualified state returned by deterministic rail sampling.
nonisolated struct PlanarTrajectorySample: Codable, Equatable, Sendable {
    let epoch: CelestialEpoch
    let state: PlanarStateVector
}
