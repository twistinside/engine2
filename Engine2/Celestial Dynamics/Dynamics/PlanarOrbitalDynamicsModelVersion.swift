/// Version of the deterministic numerical planar orbital-dynamics contract.
///
/// Save, replay, and prediction provenance retain this value because changes to
/// force summation, endpoint treatment, or integration order may change results.
nonisolated enum PlanarOrbitalDynamicsModelVersion: UInt32, Codable, Equatable, Hashable, Sendable {
    case velocityVerletV1 = 1
}
