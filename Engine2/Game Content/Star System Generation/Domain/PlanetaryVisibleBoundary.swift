/// Physical boundary expected to supply the body's visible disk.
nonisolated enum PlanetaryVisibleBoundary: UInt8, Codable, Equatable, Hashable, Sendable {
    case exposedSolid
    case opaqueAtmosphere
}
