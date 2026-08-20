import Testing
@testable import Engine2

struct PCelestialBodyTests {
    @Test func celestialAndStellarAccessorsReadLiveWorldRows() {
        let world = World()
        let entity = TestStellarEntity(
            unregisteredID: EntityID(index: 0, generation: 0),
            in: world
        )
        let bodyID = CelestialBodyID.primaryStar
        let mass = AstronomicalMass.sun
        let physicalRadius = AstronomicalDistance.solarRadius
        let orbitalState = PlanarStateVector.zero
        let gravityParticipation = GravityParticipation.sourceOnly
        let luminosity = StellarLuminosity.solarLuminosity
        let effectiveTemperature = ThermodynamicTemperature(kelvin: 5_772)
        let xuvLuminosityFraction = 0.000_1

        world.celestialIdentityComponents.insert(
            CCelestialIdentity(bodyID: bodyID, kind: .star),
            for: entity.id
        )
        world.massiveBodyComponents.insert(
            CMassiveBody(mass: mass, physicalRadius: physicalRadius),
            for: entity.id
        )
        world.orbitalMotionComponents.insert(
            COrbitalMotion(
                orbitalState: orbitalState,
                authority: .ephemerisRoot
            ),
            for: entity.id
        )
        world.gravityParticipationComponents.insert(
            CGravityParticipation(participation: gravityParticipation),
            for: entity.id
        )
        world.stellarEmissionComponents.insert(
            CStellarEmission(
                luminosity: luminosity,
                effectiveTemperature: effectiveTemperature,
                xuvLuminosityFraction: xuvLuminosityFraction
            ),
            for: entity.id
        )

        #expect(entity.celestialBodyID == bodyID)
        #expect(entity.celestialBodyKind == .star)
        #expect(entity.mass == mass)
        #expect(entity.physicalRadius == physicalRadius)
        #expect(entity.orbitalState == orbitalState)
        #expect(entity.orbitalAuthority == .ephemerisRoot)
        #expect(entity.gravityParticipation == gravityParticipation)
        #expect(entity.luminosity == luminosity)
        #expect(entity.effectiveTemperature == effectiveTemperature)
        #expect(entity.xuvLuminosityFraction == xuvLuminosityFraction)
    }
}

private extension PCelestialBodyTests {
    final class TestStellarEntity: Entity, PStellarEmitter {}
}
