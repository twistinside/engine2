/// Typed Game Content facade for a comet backed by celestial ECS state.
final class Comet: Entity, PCelestialBody {
    /// Registers a comet with explicit physical, orbital, and gravity facts.
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
            kind: .comet,
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
