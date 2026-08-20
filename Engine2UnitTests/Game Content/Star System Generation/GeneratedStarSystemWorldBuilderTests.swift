import Testing

@testable import Engine2

struct GeneratedStarSystemWorldBuilderTests {
    @Test func materializesGeneratedFactsAsIndexedCelestialComponents() throws {
        let sourceSystem = try StarSystemGenerator(
            policy: .coreAccretionLiteV1
        ).generate(seed: StarSystemSeed(rawValue: 1))
        let builder = try GeneratedStarSystemWorldBuilder(
            sourceSystem: sourceSystem,
            gravitySystemModelVersion: .planarKeplerV1
        )

        let world = builder.buildWorld()
        let expectedBodyIDs = [.primaryStar] + builder.gravitySystem.bodies.map {
            CelestialBodyID(rawValue: $0.id.rawValue)
        }

        #expect(world.celestialBodyIndex.orderedBodyIDs == expectedBodyIDs)
        #expect(world.celestialBodyIndex.count == builder.gravitySystem.bodies.count + 1)
        #expect(
            world.celestialEphemerisConfiguration?.modelVersion
                == builder.gravitySystem.modelVersion
        )
        #expect(world.celestialTimeline.epoch == builder.gravitySystem.epoch)
        #expect(world.celestialTimeline.predictionBasisRevision == .zero)
        #expect(world.positionComponents.dense.isEmpty)
        #expect(world.motionComponents.dense.isEmpty)

        let starEntityID = try #require(
            world.celestialBodyIndex[.primaryStar]
        )
        #expect(world.celestialIdentityComponents[starEntityID]?.kind == .star)
        #expect(world.massiveBodyComponents[starEntityID]?.mass == sourceSystem.star.mass)
        #expect(world.massiveBodyComponents[starEntityID]?.physicalRadius == sourceSystem.star.radius)
        #expect(world.orbitalMotionComponents[starEntityID]?.orbitalState == .zero)
        #expect(world.orbitalMotionComponents[starEntityID]?.authority == .ephemerisRoot)
        #expect(world.gravityParticipationComponents[starEntityID]?.participation == .sourceOnly)
        #expect(world.stellarEmissionComponents[starEntityID]?.luminosity == sourceSystem.star.luminosity)

        let initialStates = try GravitySystemEphemeris(
            system: builder.gravitySystem
        ).evaluatedBodyStates(at: builder.gravitySystem.epoch)
        for expected in initialStates {
            let bodyID = CelestialBodyID(rawValue: expected.body.id.rawValue)
            let entityID = try #require(world.celestialBodyIndex[bodyID])
            let expectedKind: CelestialBodyKind = expected.body.parentID == nil
                ? .planet
                : .moon
            let expectedParentID = expected.body.parentID.map {
                CelestialBodyID(rawValue: $0.rawValue)
            } ?? .primaryStar

            #expect(world.celestialIdentityComponents[entityID]?.kind == expectedKind)
            #expect(world.massiveBodyComponents[entityID]?.mass == expected.body.mass)
            #expect(world.massiveBodyComponents[entityID]?.physicalRadius == expected.body.radius)
            #expect(world.orbitalMotionComponents[entityID]?.orbitalState == expected.state)
            #expect(
                world.orbitalMotionComponents[entityID]?.authority
                    == .keplerianRail(
                        parentID: expectedParentID,
                        rail: expected.body.rail
                    )
            )
            #expect(world.gravityParticipationComponents[entityID]?.participation == .sourceOnly)
            #expect(world.stellarEmissionComponents[entityID] == nil)
        }
    }

    @Test func productionScheduleAdvancesMaterializedRailsAtTheWorldEpoch() throws {
        let sourceSystem = try StarSystemGenerator(
            policy: .coreAccretionLiteV1
        ).generate(seed: StarSystemSeed(rawValue: 1))
        let builder = try GeneratedStarSystemWorldBuilder(
            sourceSystem: sourceSystem,
            gravitySystemModelVersion: .planarKeplerV1
        )
        let expectedBody = try #require(builder.gravitySystem.bodies.first)
        let expectedBodyID = CelestialBodyID(rawValue: expectedBody.id.rawValue)
        let nextEpoch = CelestialEpoch(
            secondsSinceReferenceEpoch: SimulationRuntime.fixedTimeStep
                .doublePrecisionSeconds
        )
        let expectedState = try #require(
            GravitySystemEphemeris(system: builder.gravitySystem)
                .evaluatedBodyStates(at: nextEpoch)
                .first(where: { $0.body.id == expectedBody.id })?
                .state
        )
        let world = builder.buildWorld()
        let engine = Engine(
            world: world,
            fixedTimeStep: SimulationRuntime.fixedTimeStep,
            configuration: .basicGame
        )

        engine.step()

        let entityID = try #require(world.celestialBodyIndex[expectedBodyID])
        #expect(world.celestialTimeline.epoch == nextEpoch)
        #expect(world.celestialTimeline.predictionBasisRevision == .zero)
        #expect(world.orbitalMotionComponents[entityID]?.orbitalState == expectedState)
        #expect(
            world.orbitalMotionComponents[
                try #require(world.celestialBodyIndex[.primaryStar])
            ]?.orbitalState == .zero
        )
    }
}
