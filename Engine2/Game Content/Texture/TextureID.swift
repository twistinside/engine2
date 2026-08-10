/// Exhaustive Game Content identity for packaged texture assets.
///
/// Render carries these backend-neutral values through authored descriptions
/// and resolves them through the selected catalog. The identity exposes no
/// decoded pixels or GPU resource.
nonisolated enum TextureID: CaseIterable, Codable, Hashable, Sendable {
    case terrestrialPlanetElevation
    case terrestrialPlanetSurface
    case terrestrialPlanetControl
    case terrestrialPlanetClouds
}
