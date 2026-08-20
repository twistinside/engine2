import Testing
@testable import Engine2

struct CelestialEntityTests {
    @Test func concreteFacadesRegisterTheirKindsAndRequiredRows() {
        let world = World()
        let star = Star(
            in: world,
            bodyID: .primaryStar,
            mass: .sun,
            physicalRadius: .solarRadius,
            orbitalState: .zero,
            orbitalAuthority: .ephemerisRoot,
            gravityParticipation: .sourceOnly,
            luminosity: .solarLuminosity,
            effectiveTemperature: ThermodynamicTemperature(kelvin: 5_772),
            xuvLuminosityFraction: 0.000_1
        )
        let planet = Planet(
            in: world,
            bodyID: CelestialBodyID(rawValue: 1),
            mass: .earth,
            physicalRadius: .earthRadius,
            orbitalState: .zero,
            orbitalAuthority: .integrated,
            gravityParticipation: .sourceAndReceiver
        )
        let moon = Moon(
            in: world,
            bodyID: CelestialBodyID(rawValue: 2),
            mass: AstronomicalMass(kilograms: 7.342e22),
            physicalRadius: AstronomicalDistance(meters: 1_737_400),
            orbitalState: .zero,
            orbitalAuthority: .integrated,
            gravityParticipation: .sourceAndReceiver
        )
        let comet = Comet(
            in: world,
            bodyID: CelestialBodyID(rawValue: 3),
            mass: AstronomicalMass(kilograms: 1e14),
            physicalRadius: AstronomicalDistance(meters: 2_000),
            orbitalState: .zero,
            orbitalAuthority: .integrated,
            gravityParticipation: .receiverOnly
        )
        let asteroid = Asteroid(
            in: world,
            bodyID: CelestialBodyID(rawValue: 4),
            mass: AstronomicalMass(kilograms: 1e15),
            physicalRadius: AstronomicalDistance(meters: 5_000),
            orbitalState: .zero,
            orbitalAuthority: .integrated,
            gravityParticipation: .receiverOnly
        )

        #expect(star.celestialBodyKind == .star)
        #expect(planet.celestialBodyKind == .planet)
        #expect(moon.celestialBodyKind == .moon)
        #expect(comet.celestialBodyKind == .comet)
        #expect(asteroid.celestialBodyKind == .asteroid)
        #expect(world.celestialIdentityComponents.dense.count == 5)
        #expect(world.massiveBodyComponents.dense.count == 5)
        #expect(world.orbitalMotionComponents.dense.count == 5)
        #expect(world.gravityParticipationComponents.dense.count == 5)
        #expect(world.stellarEmissionComponents.entities == [star.id])
        #expect(world.celestialBodyIndex.orderedBodyIDs == (0...4).map { CelestialBodyID(rawValue: UInt64($0)) })
    }
}
