import Testing
import simd

@testable import Engine2

nonisolated struct PlanarGravityFieldTests {
    @Test func circularOrbitReceivesExpectedStarwardAcceleration() throws {
        let system = onePlanetSystem()
        let body = try #require(system.bodies.first)
        let ephemeris = try GravitySystemEphemeris(system: system)
        let field = PlanarGravityField(ephemeris: ephemeris)
        let state = try #require(ephemeris.state(for: body.id, at: system.epoch))

        let acceleration = try field.acceleration(
            at: state.position,
            epoch: system.epoch,
            excluding: body.id
        )
        let expectedMagnitude = GravitationalParameter(
            primaryMass: system.starMass,
            orbitingMass: .zero
        ).cubicMetersPerSecondSquared / (
            body.rail.semiMajorAxis.meters * body.rail.semiMajorAxis.meters
        )
        let expectedDirection = -state.position.meters / simd_length(state.position.meters)
        let expectedAcceleration = expectedDirection * expectedMagnitude

        #expect(
            approximatelyEqual(
                acceleration.metersPerSecondSquared.x,
                expectedAcceleration.x
            )
        )
        #expect(
            approximatelyEqual(
                acceleration.metersPerSecondSquared.y,
                expectedAcceleration.y
            )
        )
    }

    private func onePlanetSystem() -> GeneratedGravitySystem {
        let seed = StarSystemSeed(rawValue: 0)
        let bodyID = GeneratedBodyID.planet(formationIndex: 0)
        let body = GravityRailBody(
            id: bodyID,
            parentID: nil,
            mass: .earth,
            radius: .earthRadius,
            rail: PlanarKeplerianRail(
                semiMajorAxis: .astronomicalUnit,
                eccentricity: .circular,
                longitudeOfPeriapsisRadians: GravitySystemGenerator.phase(
                    seed: seed,
                    modelVersion: .planarKeplerV1,
                    bodyID: bodyID,
                    domain: GravitySystemGenerator.periapsisDomain
                ),
                meanAnomalyAtEpochRadians: GravitySystemGenerator.phase(
                    seed: seed,
                    modelVersion: .planarKeplerV1,
                    bodyID: bodyID,
                    domain: GravitySystemGenerator.meanAnomalyDomain
                ),
                epoch: .zero,
                gravitationalParameter: GravitationalParameter(
                    primaryMass: .sun,
                    orbitingMass: .earth
                )
            )
        )
        return GeneratedGravitySystem(
            seed: seed,
            modelVersion: .planarKeplerV1,
            epoch: .zero,
            starMass: .sun,
            starRadius: .solarRadius,
            bodies: [body]
        )
    }

    private func approximatelyEqual(_ first: Double, _ second: Double) -> Bool {
        let scale = max(abs(first), abs(second), 1)
        return abs(first - second) <= scale * 1e-12
    }
}
