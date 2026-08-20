import Testing

@testable import Engine2

struct SOrbitalDynamicsTests {
    @Test func wrapperCommitsTheSharedStepperResultAndTimelineTogether() throws {
        var world = World()
        world.celestialEphemerisConfiguration = CelestialEphemerisConfiguration(
            modelVersion: .planarKeplerV1
        )
        let probeID = CelestialBodyID(rawValue: 1)
        let sourceMass = AstronomicalMass(kilograms: 1e15)
        let sourceRadius = AstronomicalDistance(meters: 10)
        let probeState = PlanarStateVector(
            position: PlanarPosition(meters: SIMD2(1_000, 0)),
            velocity: PlanarVelocity(metersPerSecond: SIMD2(0, 10))
        )
        _ = Star(
            in: world,
            bodyID: .primaryStar,
            mass: sourceMass,
            physicalRadius: sourceRadius,
            orbitalState: .zero,
            orbitalAuthority: .ephemerisRoot,
            gravityParticipation: .sourceOnly,
            luminosity: .solarLuminosity,
            effectiveTemperature: ThermodynamicTemperature(kelvin: 5_772),
            xuvLuminosityFraction: 0.000_1
        )
        let probe = Comet(
            in: world,
            bodyID: probeID,
            mass: AstronomicalMass(kilograms: 1),
            physicalRadius: AstronomicalDistance(meters: 1),
            orbitalState: probeState,
            orbitalAuthority: .integrated,
            gravityParticipation: .receiverOnly
        )
        let expectedResult = try PlanarOrbitalDynamicsStepper(
            modelVersion: .velocityVerletV1
        ).step(
            bodies: [
                PlanarOrbitalBody(
                    id: .primaryStar,
                    massKilograms: sourceMass.kilograms,
                    radiusMeters: sourceRadius.meters,
                    initialState: .zero,
                    propagation: .prescribed(endState: .zero),
                    gravityParticipation: .sourceOnly
                ),
                PlanarOrbitalBody(
                    id: probeID,
                    massKilograms: 1,
                    radiusMeters: 1,
                    initialState: probeState,
                    propagation: .integrated,
                    gravityParticipation: .receiverOnly
                )
            ],
            durationSeconds: 1
        )
        let expectedProbeState = try #require(
            expectedResult.state(for: probeID)
        )
        let system = SOrbitalDynamics(
            modelVersion: .velocityVerletV1,
            durationSeconds: 1
        )

        try system.advance(world: &world)

        #expect(probe.orbitalState == expectedProbeState)
        #expect(
            world.celestialTimeline.epoch
                == CelestialEpoch(secondsSinceReferenceEpoch: 1)
        )
        #expect(world.celestialTimeline.predictionBasisRevision == .zero)
    }

    @Test func typedRefusalLeavesEveryAuthoritativeValueUnchanged() {
        var world = World()
        world.celestialEphemerisConfiguration = CelestialEphemerisConfiguration(
            modelVersion: .planarKeplerV1
        )
        let star = Star(
            in: world,
            bodyID: .primaryStar,
            mass: .sun,
            physicalRadius: .solarRadius,
            orbitalState: .zero,
            orbitalAuthority: .ephemerisRoot,
            gravityParticipation: .sourceAndReceiver,
            luminosity: .solarLuminosity,
            effectiveTemperature: ThermodynamicTemperature(kelvin: 5_772),
            xuvLuminosityFraction: 0.000_1
        )
        let initialState = star.orbitalState
        let initialTimeline = world.celestialTimeline
        let system = SOrbitalDynamics(
            modelVersion: .velocityVerletV1,
            durationSeconds: 1
        )

        #expect(
            throws: OrbitalDynamicsSystemError
                .invalidPrescribedGravityParticipation(.primaryStar)
        ) {
            try system.advance(world: &world)
        }

        #expect(star.orbitalState == initialState)
        #expect(world.celestialTimeline == initialTimeline)
    }

    @Test func missingEphemerisProvenanceRefusesWithoutMutation() {
        var world = World()
        let planetID = CelestialBodyID(rawValue: 1)
        let starMass = AstronomicalMass(kilograms: 1e15)
        let planetMass = AstronomicalMass(kilograms: 1)
        let rail = PlanarKeplerianRail(
            semiMajorAxis: AstronomicalDistance(meters: 1_000),
            eccentricity: .circular,
            longitudeOfPeriapsisRadians: 0,
            meanAnomalyAtEpochRadians: 0,
            epoch: .zero,
            gravitationalParameter: GravitationalParameter(
                primaryMass: starMass,
                orbitingMass: planetMass
            )
        )
        let star = Star(
            in: world,
            bodyID: .primaryStar,
            mass: starMass,
            physicalRadius: AstronomicalDistance(meters: 10),
            orbitalState: .zero,
            orbitalAuthority: .ephemerisRoot,
            gravityParticipation: .sourceOnly,
            luminosity: .solarLuminosity,
            effectiveTemperature: ThermodynamicTemperature(kelvin: 5_772),
            xuvLuminosityFraction: 0.000_1
        )
        let planetState = PlanarKeplerPropagationKernel().state(
            on: rail,
            at: .zero
        )
        let planet = Planet(
            in: world,
            bodyID: planetID,
            mass: planetMass,
            physicalRadius: AstronomicalDistance(meters: 1),
            orbitalState: planetState,
            orbitalAuthority: .keplerianRail(
                parentID: .primaryStar,
                rail: rail
            ),
            gravityParticipation: .sourceOnly
        )
        let initialStarState = star.orbitalState
        let initialPlanetState = planet.orbitalState
        let initialTimeline = world.celestialTimeline
        let system = SOrbitalDynamics(
            modelVersion: .velocityVerletV1,
            durationSeconds: 1
        )

        #expect(throws: OrbitalDynamicsSystemError.missingEphemerisConfiguration) {
            try system.advance(world: &world)
        }

        #expect(star.orbitalState == initialStarState)
        #expect(planet.orbitalState == initialPlanetState)
        #expect(world.celestialEphemerisConfiguration == nil)
        #expect(world.celestialTimeline == initialTimeline)
    }

    @Test func allIntegratedTwoBodyWorldMatchesTheSharedMutualGravityStep() throws {
        var world = World()
        let planetID = CelestialBodyID(rawValue: 1)
        let starMass = AstronomicalMass(kilograms: 2e20)
        let planetMass = AstronomicalMass(kilograms: 1e20)
        let radius = AstronomicalDistance(meters: 1)
        let starState = PlanarStateVector(
            position: PlanarPosition(meters: SIMD2(-500_000, 0)),
            velocity: .zero
        )
        let planetState = PlanarStateVector(
            position: PlanarPosition(meters: SIMD2(500_000, 0)),
            velocity: .zero
        )
        let star = Star(
            in: world,
            bodyID: .primaryStar,
            mass: starMass,
            physicalRadius: radius,
            orbitalState: starState,
            orbitalAuthority: .integrated,
            gravityParticipation: .sourceAndReceiver,
            luminosity: .solarLuminosity,
            effectiveTemperature: ThermodynamicTemperature(kelvin: 5_772),
            xuvLuminosityFraction: 0.000_1
        )
        let planet = Planet(
            in: world,
            bodyID: planetID,
            mass: planetMass,
            physicalRadius: radius,
            orbitalState: planetState,
            orbitalAuthority: .integrated,
            gravityParticipation: .sourceAndReceiver
        )
        let expectedResult = try PlanarOrbitalDynamicsStepper(
            modelVersion: .velocityVerletV1
        ).step(
            bodies: [
                PlanarOrbitalBody(
                    id: .primaryStar,
                    massKilograms: starMass.kilograms,
                    radiusMeters: radius.meters,
                    initialState: starState,
                    propagation: .integrated,
                    gravityParticipation: .sourceAndReceiver
                ),
                PlanarOrbitalBody(
                    id: planetID,
                    massKilograms: planetMass.kilograms,
                    radiusMeters: radius.meters,
                    initialState: planetState,
                    propagation: .integrated,
                    gravityParticipation: .sourceAndReceiver
                )
            ],
            durationSeconds: 1
        )
        let expectedStarState = try #require(
            expectedResult.state(for: .primaryStar)
        )
        let expectedPlanetState = try #require(
            expectedResult.state(for: planetID)
        )
        let system = SOrbitalDynamics(
            modelVersion: .velocityVerletV1,
            durationSeconds: 1
        )

        try system.advance(world: &world)

        #expect(star.orbitalState == expectedStarState)
        #expect(planet.orbitalState == expectedPlanetState)
        #expect(
            world.celestialTimeline.epoch
                == CelestialEpoch(secondsSinceReferenceEpoch: 1)
        )
        #expect(world.celestialTimeline.predictionBasisRevision == .zero)
    }

    @Test func emptyWorldDoesNotInventACelestialTimeline() throws {
        var world = World()
        let system = SOrbitalDynamics(
            modelVersion: .velocityVerletV1,
            durationSeconds: 1
        )

        try system.advance(world: &world)

        #expect(world.celestialTimeline.epoch == .zero)
        #expect(world.celestialTimeline.predictionBasisRevision == .zero)
    }

    @Test func unindexedCelestialRowsCannotMasqueradeAsAnEmptyWorld() {
        var world = World()
        let entityID = EntityID(index: 0, generation: 0)
        world.celestialIdentityComponents.insert(
            CCelestialIdentity(bodyID: .primaryStar, kind: .star),
            for: entityID
        )
        let initialTimeline = world.celestialTimeline
        let system = SOrbitalDynamics(
            modelVersion: .velocityVerletV1,
            durationSeconds: 1
        )

        #expect(throws: OrbitalDynamicsSystemError.componentCardinalityMismatch) {
            try system.advance(world: &world)
        }

        #expect(world.celestialTimeline == initialTimeline)
    }
}
