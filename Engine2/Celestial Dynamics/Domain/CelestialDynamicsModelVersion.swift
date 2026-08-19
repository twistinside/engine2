/// Version of the deterministic planar celestial-dynamics contract.
///
/// A new case is required when rail evaluation, phase interpretation, gravity,
/// or transfer calculations change saved or replayed results.
nonisolated enum CelestialDynamicsModelVersion: UInt32, Codable, Equatable, Hashable, Sendable {
    case planarKeplerV1 = 1
}
