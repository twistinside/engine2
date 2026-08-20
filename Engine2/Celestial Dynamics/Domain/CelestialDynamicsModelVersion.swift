/// Version of the deterministic planar celestial-dynamics contract.
///
/// A new case is required when phase interpretation or rail propagation changes
/// saved or replayed results.
nonisolated enum CelestialDynamicsModelVersion: UInt32, Codable, Equatable, Hashable, Sendable {
    case planarKeplerV1 = 1
}
