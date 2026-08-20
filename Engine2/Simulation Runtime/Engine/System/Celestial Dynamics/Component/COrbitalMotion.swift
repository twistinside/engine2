/// Absolute planar state and the authority responsible for advancing it.
///
/// Every row describes state at the World-owned ``CelestialTimeline`` epoch.
/// Rail states are evaluated from absolute epoch, while integrated states are
/// advanced by the celestial-dynamics system through the shared mechanics.
struct COrbitalMotion: PComponent, Sendable {
    var orbitalState: PlanarStateVector
    let authority: Authority

    /// Exclusive source of one body's committed orbital state.
    enum Authority: Codable, Equatable, Sendable {
        /// Root state evaluated directly by the system ephemeris.
        case ephemerisRoot

        /// Parent-relative analytic rail composed into an absolute state.
        case keplerianRail(
            parentID: CelestialBodyID,
            rail: PlanarKeplerianRail
        )

        /// State advanced numerically through the shared orbital mechanics.
        case integrated
    }
}
