import Testing
import simd

@testable import Engine2

nonisolated struct PlanarEphemerisEvaluatorTests {
    @Test func evaluatorComposesRootPlanetAndMoonStatesInStableIdentityOrder() throws {
        let planetID = CelestialBodyID(rawValue: 10)
        let moonID = CelestialBodyID(rawValue: 20)
        let rootState = PlanarStateVector(
            position: PlanarPosition(meters: SIMD2(1_000, 2_000)),
            velocity: PlanarVelocity(metersPerSecond: SIMD2(0.5, -0.25))
        )
        let definition = try PlanarEphemerisDefinition(
            bodies: [
                .root(id: .primaryStar, state: rootState),
                .parentRelativeRail(
                    id: planetID,
                    parentID: .primaryStar,
                    rail: circularRail(
                        radiusMeters: 100,
                        gravitationalParameter: 100
                    )
                ),
                .parentRelativeRail(
                    id: moonID,
                    parentID: planetID,
                    rail: circularRail(
                        radiusMeters: 10,
                        gravitationalParameter: 10
                    )
                )
            ]
        )

        let states = try PlanarEphemerisEvaluator(
            definition: definition
        ).states(at: .zero)
        let planetBodyState = try #require(
            states.first { $0.id == planetID }
        )
        let moonBodyState = try #require(
            states.first { $0.id == moonID }
        )

        #expect(states.map(\.id) == [.primaryStar, planetID, moonID])
        #expect(states.first?.state == rootState)
        #expect(planetBodyState.state.position.meters == SIMD2(1_100, 2_000))
        #expect(planetBodyState.state.velocity.metersPerSecond == SIMD2(0.5, 0.75))
        #expect(moonBodyState.state.position.meters == SIMD2(1_110, 2_000))
        #expect(moonBodyState.state.velocity.metersPerSecond == SIMD2(0.5, 1.75))
    }

    @Test func definitionRejectsMissingParentsAndHierarchyCycles() {
        let firstID = CelestialBodyID(rawValue: 1)
        let secondID = CelestialBodyID(rawValue: 2)
        let unknownID = CelestialBodyID(rawValue: 99)
        let rail = circularRail(
            radiusMeters: 100,
            gravitationalParameter: 100
        )

        #expect(
            throws: PlanarEphemerisError.missingParent(
                body: firstID,
                parent: unknownID
            )
        ) {
            try PlanarEphemerisDefinition(
                bodies: [
                    .root(id: .primaryStar, state: .zero),
                    .parentRelativeRail(
                        id: firstID,
                        parentID: unknownID,
                        rail: rail
                    )
                ]
            )
        }
        #expect(throws: PlanarEphemerisError.hierarchyCycle(firstID)) {
            try PlanarEphemerisDefinition(
                bodies: [
                    .root(id: .primaryStar, state: .zero),
                    .parentRelativeRail(
                        id: firstID,
                        parentID: secondID,
                        rail: rail
                    ),
                    .parentRelativeRail(
                        id: secondID,
                        parentID: firstID,
                        rail: rail
                    )
                ]
            )
        }
    }

    private func circularRail(
        radiusMeters: Double,
        gravitationalParameter: Double
    ) -> PlanarKeplerianRail {
        PlanarKeplerianRail(
            semiMajorAxis: AstronomicalDistance(meters: radiusMeters),
            eccentricity: .circular,
            longitudeOfPeriapsisRadians: 0,
            meanAnomalyAtEpochRadians: 0,
            epoch: .zero,
            gravitationalParameter: GravitationalParameter(
                cubicMetersPerSecondSquared: gravitationalParameter
            )
        )
    }
}
