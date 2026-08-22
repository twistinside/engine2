/// Authored material families supported by the current Render Runtime.
///
/// Game Content selects one immutable backend-neutral description. Render
/// resolves the case into its private pipelines, textures, and draw phases
/// without switching on a Game Content material identity.
nonisolated enum RenderMaterialDescription: Equatable, Sendable {
    case opaquePBR(PBRMaterialDescription)
    case terrestrialPlanet(TerrestrialPlanetDescription)
}
