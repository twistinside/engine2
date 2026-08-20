/// Detached identity-qualified state in the shared planar orbital frame.
///
/// Ephemeris evaluation and numerical propagation return this value without
/// retaining or mutating the storage that supplied their inputs.
nonisolated struct PlanarOrbitalBodyState: Codable, Equatable, Sendable {
    let id: CelestialBodyID
    let state: PlanarStateVector
}
