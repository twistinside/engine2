/// Typed Game Content facade for a stellar entity backed by celestial ECS state.
///
/// The object retains only its inherited World identity. Its mass, motion,
/// gravity role, and emission remain authoritative component rows.
final class Star: Entity, PStellarEmitter {
    /// Registers a star with explicit physical, orbital, gravity, and emission facts.
    convenience init(
        in world: World,
        bodyID: CelestialBodyID,
        mass: AstronomicalMass,
        physicalRadius: AstronomicalDistance,
        orbitalState: PlanarStateVector,
        orbitalAuthority: COrbitalMotion.Authority,
        gravityParticipation: GravityParticipation,
        luminosity: StellarLuminosity,
        effectiveTemperature: ThermodynamicTemperature,
        xuvLuminosityFraction: Double
    ) {
        self.init(unregisteredID: world.reserveEntityID(), in: world)
        let stellarEmission = CStellarEmission(
            luminosity: luminosity,
            effectiveTemperature: effectiveTemperature,
            xuvLuminosityFraction: xuvLuminosityFraction
        )
        let initialState = CelestialBodyInitialState(
            bodyID: bodyID,
            kind: .star,
            mass: mass,
            physicalRadius: physicalRadius,
            orbitalState: orbitalState,
            orbitalAuthority: orbitalAuthority,
            gravityParticipation: gravityParticipation,
            stellarEmission: stellarEmission
        )
        world.addCelestialBody(self, from: initialState)
    }
}
