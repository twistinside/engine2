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

    @Test func precomputedEphemerisSnapshotProducesExactlyEqualAcceleration() throws {
        let sourceSystem = try StarSystemGenerator(policy: .coreAccretionLiteV1).generate(
            seed: StarSystemSeed(rawValue: 67)
        )
        let system = try GravitySystemGenerator(modelVersion: .planarKeplerV1).generate(
            from: sourceSystem
        )
        let ephemeris = try GravitySystemEphemeris(system: system)
        let field = PlanarGravityField(ephemeris: ephemeris)
        let epoch = system.epoch.advanced(by: AstronomicalDuration(seconds: 123_456))
        let snapshot = ephemeris.snapshot(at: epoch)
        let sourceState = try #require(snapshot.bodyStates.first)

        let epochAcceleration = try field.acceleration(
            at: sourceState.state.position,
            epoch: epoch,
            excluding: sourceState.body.id
        )
        let precomputedAcceleration = try field.acceleration(
            at: sourceState.state.position,
            from: snapshot,
            excluding: sourceState.body.id
        )

        #expect(precomputedAcceleration == epochAcceleration)
    }

    @Test func ephemerisSnapshotPreservesCompleteStableOrderAndProvenance() throws {
        let sourceSystem = try StarSystemGenerator(policy: .coreAccretionLiteV1).generate(
            seed: StarSystemSeed(rawValue: 1)
        )
        let system = try GravitySystemGenerator(modelVersion: .planarKeplerV1).generate(
            from: sourceSystem
        )
        let ephemeris = try GravitySystemEphemeris(system: system)
        let epoch = system.epoch.advanced(by: AstronomicalDuration(seconds: 42))

        let snapshot = ephemeris.snapshot(at: epoch)

        #expect(snapshot.system == system)
        #expect(snapshot.seed == system.seed)
        #expect(snapshot.modelVersion == system.modelVersion)
        #expect(snapshot.epoch == epoch)
        #expect(snapshot.bodyStates.map(\.body.id) == system.bodies.map(\.id))
    }

    @Test func fieldRejectsSnapshotFromAnotherGeneratedSystem() throws {
        let system = onePlanetSystem(seed: StarSystemSeed(rawValue: 0))
        let foreignSystem = onePlanetSystem(seed: StarSystemSeed(rawValue: 1))
        let field = PlanarGravityField(
            ephemeris: try GravitySystemEphemeris(system: system)
        )
        let foreignSnapshot = try GravitySystemEphemeris(
            system: foreignSystem
        ).snapshot(at: foreignSystem.epoch)
        let foreignState = try #require(foreignSnapshot.bodyStates.first)

        #expect(throws: PlanarGravityFieldError.snapshotSystemMismatch) {
            try field.acceleration(
                at: foreignState.state.position,
                from: foreignSnapshot,
                excluding: foreignState.body.id
            )
        }
    }

    @Test func fieldRejectsContactWithTheStarOrOneGeneratedBody() throws {
        let system = onePlanetSystem()
        let ephemeris = try GravitySystemEphemeris(system: system)
        let field = PlanarGravityField(ephemeris: ephemeris)
        let body = try #require(system.bodies.first)
        let bodyState = try #require(ephemeris.state(for: body.id, at: system.epoch))

        #expect(throws: PlanarGravityFieldError.contactWithStar) {
            try field.acceleration(at: PlanarPosition(meters: .zero), epoch: system.epoch)
        }
        #expect(throws: PlanarGravityFieldError.contactWithBody(body.id)) {
            try field.acceleration(at: bodyState.position, epoch: system.epoch)
        }
    }

    @Test func fieldRejectsANonfiniteInverseSquareSum() throws {
        let system = GeneratedGravitySystem(
            seed: StarSystemSeed(rawValue: 0),
            modelVersion: .planarKeplerV1,
            epoch: .zero,
            starMass: .sun,
            starRadius: AstronomicalDistance(meters: 1e-151),
            bodies: []
        )
        let field = PlanarGravityField(
            ephemeris: try GravitySystemEphemeris(system: system)
        )
        let position = PlanarPosition(meters: SIMD2(2e-151, 0))

        #expect(throws: PlanarGravityFieldError.nonfiniteAcceleration) {
            try field.acceleration(at: position, epoch: system.epoch)
        }
    }

    private func onePlanetSystem(
        seed: StarSystemSeed = StarSystemSeed(rawValue: 0)
    ) -> GeneratedGravitySystem {
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
                    domain: .longitudeOfPeriapsis
                ),
                meanAnomalyAtEpochRadians: GravitySystemGenerator.phase(
                    seed: seed,
                    modelVersion: .planarKeplerV1,
                    bodyID: bodyID,
                    domain: .meanAnomalyAtEpoch
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
