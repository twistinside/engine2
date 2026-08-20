/// Complete component seed for registering one celestial entity.
///
/// The value is the Simulation-owned admission boundary between a typed entity
/// facade and the four mandatory celestial component rows plus optional
/// stellar emission. It owns no live ECS state after registration.
struct CelestialBodyInitialState: Sendable {
    let identity: CCelestialIdentity
    let massiveBody: CMassiveBody
    let orbitalMotion: COrbitalMotion
    let gravityParticipation: CGravityParticipation
    let stellarEmission: CStellarEmission?

    init(
        bodyID: CelestialBodyID,
        kind: CelestialBodyKind,
        mass: AstronomicalMass,
        physicalRadius: AstronomicalDistance,
        orbitalState: PlanarStateVector,
        orbitalAuthority: COrbitalMotion.Authority,
        gravityParticipation: GravityParticipation,
        stellarEmission: CStellarEmission?
    ) {
        precondition(
            (kind == .star) == (stellarEmission != nil),
            "Stellar emission is required exactly when the celestial body is a star."
        )
        self.identity = CCelestialIdentity(bodyID: bodyID, kind: kind)
        self.massiveBody = CMassiveBody(
            mass: mass,
            physicalRadius: physicalRadius
        )
        self.orbitalMotion = COrbitalMotion(
            orbitalState: orbitalState,
            authority: orbitalAuthority
        )
        self.gravityParticipation = CGravityParticipation(
            participation: gravityParticipation
        )
        self.stellarEmission = stellarEmission
    }
}
