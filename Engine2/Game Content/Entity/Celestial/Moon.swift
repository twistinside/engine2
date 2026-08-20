/// Typed Game Content facade for a natural satellite backed by celestial ECS state.
final class Moon: Entity, PCelestialBody {
    /// Registers a moon with explicit physical, orbital, and gravity facts.
    convenience init(
        in world: World,
        bodyID: CelestialBodyID,
        mass: AstronomicalMass,
        physicalRadius: AstronomicalDistance,
        orbitalState: PlanarStateVector,
        orbitalAuthority: COrbitalMotion.Authority,
        gravityParticipation: GravityParticipation
    ) {
        self.init(unregisteredID: world.reserveEntityID(), in: world)
        let initialState = CelestialBodyInitialState(
            bodyID: bodyID,
            kind: .moon,
            mass: mass,
            physicalRadius: physicalRadius,
            orbitalState: orbitalState,
            orbitalAuthority: orbitalAuthority,
            gravityParticipation: gravityParticipation,
            stellarEmission: nil
        )
        world.addCelestialBody(self, from: initialState)
    }
}
