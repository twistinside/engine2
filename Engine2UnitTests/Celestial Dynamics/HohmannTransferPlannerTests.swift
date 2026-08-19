import Darwin
import Testing
import simd

@testable import Engine2

nonisolated struct HohmannTransferPlannerTests {
    @Test func outwardEarthMarsReferencePinsWindowTransferAndKernelEndpoints() throws {
        let system = earthMarsReferenceSystem()
        let plan = try HohmannTransferPlanner(system: system).plan(
            from: .planet(formationIndex: 0),
            to: .planet(formationIndex: 1),
            noEarlierThan: .zero
        )
        let kernel = PlanarKeplerPropagationKernel()
        let departure = kernel.state(on: plan.transferRail, at: plan.departureEpoch)
        let arrival = kernel.state(on: plan.transferRail, at: plan.arrivalEpoch)
        let samples = kernel.samples(
            on: plan.transferRail,
            from: plan.departureEpoch,
            through: plan.arrivalEpoch,
            sampleCount: 65
        )

        #expect(plan.nextWindowWait.seconds.bitPattern == 0x417E_CDE0_8017_B3BA)
        #expect(plan.arrivalEpoch.secondsSinceReferenceEpoch.bitPattern == 0x418A_111F_3B4D_41DA)
        #expect(plan.transferDuration.seconds.bitPattern == 0x4175_545D_F682_CFFA)
        #expect(plan.requiredPhaseAngleRadians.bitPattern == 0x3FE8_C436_8AE4_3780)
        #expect(plan.departureDeltaVMetersPerSecond.bitPattern == 0x40A7_0177_B1E5_FEF8)
        #expect(plan.arrivalDeltaVMetersPerSecond.bitPattern == 0x40A4_B1DE_DCF9_AE50)
        #expect(plan.totalDeltaVMetersPerSecond.bitPattern == 0x40B5_D9AB_476F_D6A4)
        #expect(plan.departureEpoch == CelestialEpoch.zero.advanced(by: plan.nextWindowWait))
        #expect(plan.arrivalEpoch == plan.departureEpoch.advanced(by: plan.transferDuration))
        #expect(
            approximatelyEqual(
                simd_length(departure.position.meters),
                plan.sourceReferenceRadius.meters
            )
        )
        #expect(
            approximatelyEqual(
                simd_length(arrival.position.meters),
                plan.destinationReferenceRadius.meters
            )
        )
        try expectReferenceAlignment(
            for: plan,
            in: system,
            departure: departure,
            arrival: arrival
        )
        #expect(samples.first?.state == departure)
        #expect(samples.last?.state == arrival)
    }

    @Test func inwardMarsEarthReferencePinsWindowTransferAndKernelEndpoints() throws {
        let system = earthMarsReferenceSystem()
        let plan = try HohmannTransferPlanner(system: system).plan(
            from: .planet(formationIndex: 1),
            to: .planet(formationIndex: 0),
            noEarlierThan: .zero
        )
        let kernel = PlanarKeplerPropagationKernel()
        let departure = kernel.state(on: plan.transferRail, at: plan.departureEpoch)
        let arrival = kernel.state(on: plan.transferRail, at: plan.arrivalEpoch)

        #expect(plan.nextWindowWait.seconds.bitPattern == 0x4179_4E85_3324_7341)
        #expect(plan.arrivalEpoch.secondsSinceReferenceEpoch.bitPattern == 0x4187_5171_94D3_A19D)
        #expect(plan.transferDuration.seconds.bitPattern == 0x4175_545D_F682_CFF9)
        #expect(plan.requiredPhaseAngleRadians.bitPattern == 0x4013_E310_BE82_F6E4)
        #expect(plan.departureDeltaVMetersPerSecond.bitPattern == 0x40A4_B1DE_DCF9_AE50)
        #expect(plan.arrivalDeltaVMetersPerSecond.bitPattern == 0x40A7_0177_B1E5_FEF8)
        #expect(plan.totalDeltaVMetersPerSecond.bitPattern == 0x40B5_D9AB_476F_D6A4)
        #expect(plan.transferRail.meanAnomalyAtEpochRadians == Double.pi)
        #expect(
            approximatelyEqual(
                simd_length(departure.position.meters),
                plan.sourceReferenceRadius.meters
            )
        )
        #expect(
            approximatelyEqual(
                simd_length(arrival.position.meters),
                plan.destinationReferenceRadius.meters
            )
        )
        try expectReferenceAlignment(
            for: plan,
            in: system,
            departure: departure,
            arrival: arrival
        )
    }

    @Test func distinctRadiiWithIndistinguishableMeanMotionsReturnTypedRefusal() throws {
        let sourceRadius = AstronomicalDistance(meters: 3e13)
        let system = twoPlanetReferenceSystem(
            sourceSemiMajorAxis: sourceRadius,
            destinationSemiMajorAxis: AstronomicalDistance(meters: sourceRadius.meters.nextUp)
        )
        let planner = try HohmannTransferPlanner(system: system)

        #expect(throws: HohmannTransferError.coincidentReferenceOrbits) {
            try planner.plan(
                from: .planet(formationIndex: 0),
                to: .planet(formationIndex: 1),
                noEarlierThan: .zero
            )
        }
    }

    @Test func unknownBodyReturnsTypedRefusal() throws {
        let unknownBodyID = GeneratedBodyID.planet(formationIndex: 99)
        let planner = try HohmannTransferPlanner(system: earthMarsReferenceSystem())

        #expect(throws: HohmannTransferError.unknownBody(unknownBodyID)) {
            try planner.plan(
                from: unknownBodyID,
                to: .planet(formationIndex: 0),
                noEarlierThan: .zero
            )
        }
    }

    @Test func identicalBodiesReturnTypedRefusal() throws {
        let bodyID = GeneratedBodyID.planet(formationIndex: 0)
        let planner = try HohmannTransferPlanner(system: earthMarsReferenceSystem())

        #expect(throws: HohmannTransferError.identicalBodies(bodyID)) {
            try planner.plan(
                from: bodyID,
                to: bodyID,
                noEarlierThan: .zero
            )
        }
    }

    @Test func moonSelectionReturnsTypedRefusal() throws {
        let system = earthMarsReferenceSystemWithMoon()
        let moonID = GeneratedBodyID.moon(
            parent: .planet(formationIndex: 0),
            formationIndex: 0
        )
        let planner = try HohmannTransferPlanner(system: system)

        #expect(throws: HohmannTransferError.requiresPlanet(moonID)) {
            try planner.plan(
                from: moonID,
                to: .planet(formationIndex: 1),
                noEarlierThan: .zero
            )
        }
    }

    @Test func planningBeforeTheSystemEpochReturnsTypedRefusal() throws {
        let systemEpoch = CelestialEpoch(secondsSinceReferenceEpoch: 100)
        let system = twoPlanetReferenceSystem(
            sourceSemiMajorAxis: .astronomicalUnit,
            destinationSemiMajorAxis: AstronomicalDistance(astronomicalUnits: 1.523679),
            epoch: systemEpoch
        )
        let planner = try HohmannTransferPlanner(system: system)

        #expect(throws: HohmannTransferError.departureBeforeReferenceEpoch) {
            try planner.plan(
                from: .planet(formationIndex: 0),
                to: .planet(formationIndex: 1),
                noEarlierThan: .zero
            )
        }
    }

    @Test func epochWhoseTransferCannotAdvanceReturnsTypedRefusal() throws {
        let planner = try HohmannTransferPlanner(system: earthMarsReferenceSystem())
        let unadvanceableEpoch = CelestialEpoch(
            secondsSinceReferenceEpoch: .greatestFiniteMagnitude
        )

        #expect(throws: HohmannTransferError.unrepresentableTransfer) {
            try planner.plan(
                from: .planet(formationIndex: 0),
                to: .planet(formationIndex: 1),
                noEarlierThan: unadvanceableEpoch
            )
        }
    }

    @Test func coarseEpochThatRoundsPositiveDurationsReturnsTypedRefusal() throws {
        let planner = try HohmannTransferPlanner(system: earthMarsReferenceSystem())
        let coarseEpoch = CelestialEpoch(secondsSinceReferenceEpoch: 1e23)
        let positiveDuration = AstronomicalDuration(seconds: 22_365_663.40693662)
        let roundedEpochSeconds = coarseEpoch.secondsSinceReferenceEpoch
            + positiveDuration.seconds

        #expect(roundedEpochSeconds > coarseEpoch.secondsSinceReferenceEpoch)
        #expect(
            roundedEpochSeconds - coarseEpoch.secondsSinceReferenceEpoch
                != positiveDuration.seconds
        )
        #expect(throws: HohmannTransferError.unrepresentableTransfer) {
            try planner.plan(
                from: .planet(formationIndex: 0),
                to: .planet(formationIndex: 1),
                noEarlierThan: coarseEpoch
            )
        }
    }

    @Test func extremeInwardTransferWhoseDestinationPhaseIsLostReturnsTypedRefusal() throws {
        let sourceRadiusMeters = 1e15
        let destinationRadiusMeters = 1e9
        let transferSemiMajorAxisMeters = sourceRadiusMeters / 2 + destinationRadiusMeters / 2
        let radiusRatio = destinationRadiusMeters / sourceRadiusMeters
        let eccentricity = (1 - radiusRatio) / (1 + radiusRatio)
        let reconstructedPeriapsis = transferSemiMajorAxisMeters * (1 - eccentricity)
        let periapsisRelativeError = abs(reconstructedPeriapsis - destinationRadiusMeters)
            / destinationRadiusMeters
        let system = twoPlanetReferenceSystem(
            sourceSemiMajorAxis: AstronomicalDistance(meters: sourceRadiusMeters),
            destinationSemiMajorAxis: AstronomicalDistance(meters: destinationRadiusMeters)
        )
        let planner = try HohmannTransferPlanner(system: system)

        #expect(periapsisRelativeError <= HohmannTransferPlanner.maximumTransferApsisRelativeError)
        #expect(throws: HohmannTransferError.unrepresentableTransfer) {
            try planner.plan(
                from: .planet(formationIndex: 0),
                to: .planet(formationIndex: 1),
                noEarlierThan: .zero
            )
        }
    }

    @Test func extremeRadiusRatioWhosePeriapsisCannotBeReconstructedReturnsTypedRefusal() throws {
        let sourceRadiusMeters = 1e25
        let destinationRadiusMeters = 1e9
        let transferSemiMajorAxisMeters = sourceRadiusMeters / 2 + destinationRadiusMeters / 2
        let radiusRatio = destinationRadiusMeters / sourceRadiusMeters
        let eccentricity = (1 - radiusRatio) / (1 + radiusRatio)
        let reconstructedPeriapsis = transferSemiMajorAxisMeters * (1 - eccentricity)
        let relativeError = abs(reconstructedPeriapsis - destinationRadiusMeters)
            / destinationRadiusMeters
        let system = twoPlanetReferenceSystem(
            sourceSemiMajorAxis: AstronomicalDistance(meters: sourceRadiusMeters),
            destinationSemiMajorAxis: AstronomicalDistance(meters: destinationRadiusMeters)
        )
        let planner = try HohmannTransferPlanner(system: system)

        #expect(relativeError > HohmannTransferPlanner.maximumTransferApsisRelativeError)
        #expect(throws: HohmannTransferError.unrepresentableTransfer) {
            try planner.plan(
                from: .planet(formationIndex: 0),
                to: .planet(formationIndex: 1),
                noEarlierThan: .zero
            )
        }
    }

    @Test func waitDurationUsesTheRequestedPlanningEpoch() throws {
        let planningEpoch = CelestialEpoch(secondsSinceReferenceEpoch: 10_000_000)
        let plan = try HohmannTransferPlanner(system: earthMarsReferenceSystem()).plan(
            from: .planet(formationIndex: 0),
            to: .planet(formationIndex: 1),
            noEarlierThan: planningEpoch
        )

        #expect(plan.planningEpoch == planningEpoch)
        #expect(plan.nextWindowWait == plan.departureEpoch.duration(since: planningEpoch))
        #expect(plan.nextWindowWait != plan.departureEpoch.duration(since: .zero))
    }

    private func earthMarsReferenceSystem() -> GeneratedGravitySystem {
        twoPlanetReferenceSystem(
            sourceSemiMajorAxis: .astronomicalUnit,
            destinationSemiMajorAxis: AstronomicalDistance(astronomicalUnits: 1.523679)
        )
    }

    private func earthMarsReferenceSystemWithMoon() -> GeneratedGravitySystem {
        let system = earthMarsReferenceSystem()
        let parentID = GeneratedBodyID.planet(formationIndex: 0)
        let moonID = GeneratedBodyID.moon(parent: parentID, formationIndex: 0)
        let moonMass = AstronomicalMass(earthMasses: 0.01)
        let moon = GravityRailBody(
            id: moonID,
            parentID: parentID,
            mass: moonMass,
            radius: AstronomicalDistance(earthRadii: 0.1),
            rail: PlanarKeplerianRail(
                semiMajorAxis: AstronomicalDistance(meters: 400_000_000),
                eccentricity: .circular,
                longitudeOfPeriapsisRadians: GravitySystemGenerator.phase(
                    seed: system.seed,
                    modelVersion: system.modelVersion,
                    bodyID: moonID,
                    domain: .longitudeOfPeriapsis
                ),
                meanAnomalyAtEpochRadians: GravitySystemGenerator.phase(
                    seed: system.seed,
                    modelVersion: system.modelVersion,
                    bodyID: moonID,
                    domain: .meanAnomalyAtEpoch
                ),
                epoch: system.epoch,
                gravitationalParameter: GravitationalParameter(
                    primaryMass: .earth,
                    orbitingMass: moonMass
                )
            )
        )
        return GeneratedGravitySystem(
            seed: system.seed,
            modelVersion: system.modelVersion,
            epoch: system.epoch,
            starMass: system.starMass,
            starRadius: system.starRadius,
            bodies: system.bodies + [moon]
        )
    }

    private func twoPlanetReferenceSystem(
        sourceSemiMajorAxis: AstronomicalDistance,
        destinationSemiMajorAxis: AstronomicalDistance,
        epoch: CelestialEpoch = .zero
    ) -> GeneratedGravitySystem {
        let seed = StarSystemSeed(rawValue: 0)
        let starMass = AstronomicalMass.sun
        let sourceID = GeneratedBodyID.planet(formationIndex: 0)
        let destinationID = GeneratedBodyID.planet(formationIndex: 1)
        let source = makePlanet(
            id: sourceID,
            mass: .earth,
            radius: .earthRadius,
            semiMajorAxis: sourceSemiMajorAxis,
            epoch: epoch,
            seed: seed,
            starMass: starMass
        )
        let destination = makePlanet(
            id: destinationID,
            mass: AstronomicalMass(earthMasses: 0.1074),
            radius: AstronomicalDistance(earthRadii: 0.532),
            semiMajorAxis: destinationSemiMajorAxis,
            epoch: epoch,
            seed: seed,
            starMass: starMass
        )
        return GeneratedGravitySystem(
            seed: seed,
            modelVersion: .planarKeplerV1,
            epoch: epoch,
            starMass: starMass,
            starRadius: .solarRadius,
            bodies: [source, destination]
        )
    }

    private func makePlanet(
        id: GeneratedBodyID,
        mass: AstronomicalMass,
        radius: AstronomicalDistance,
        semiMajorAxis: AstronomicalDistance,
        epoch: CelestialEpoch,
        seed: StarSystemSeed,
        starMass: AstronomicalMass
    ) -> GravityRailBody {
        GravityRailBody(
            id: id,
            parentID: nil,
            mass: mass,
            radius: radius,
            rail: PlanarKeplerianRail(
                semiMajorAxis: semiMajorAxis,
                eccentricity: .circular,
                longitudeOfPeriapsisRadians: GravitySystemGenerator.phase(
                    seed: seed,
                    modelVersion: .planarKeplerV1,
                    bodyID: id,
                    domain: .longitudeOfPeriapsis
                ),
                meanAnomalyAtEpochRadians: GravitySystemGenerator.phase(
                    seed: seed,
                    modelVersion: .planarKeplerV1,
                    bodyID: id,
                    domain: .meanAnomalyAtEpoch
                ),
                epoch: epoch,
                gravitationalParameter: GravitationalParameter(
                    primaryMass: starMass,
                    orbitingMass: mass
                )
            )
        )
    }

    private func approximatelyEqual(_ first: Double, _ second: Double) -> Bool {
        let scale = max(abs(first), abs(second), 1)
        return abs(first - second) <= scale * 1e-11
    }

    private func circularReferenceLongitude(
        for bodyID: GeneratedBodyID,
        in system: GeneratedGravitySystem,
        at epoch: CelestialEpoch
    ) throws -> Double {
        let body = try #require(system.bodies.first(where: { $0.id == bodyID }))
        let radiusMeters = body.rail.semiMajorAxis.meters
        let parameter = GravitationalParameter
            .newtonianGravitationalConstantCubicMetersPerKilogramSecondSquared
            * system.starMass.kilograms
        let meanMotion = (parameter / radiusMeters).squareRoot() / radiusMeters
        let period = 2 * Double.pi / meanMotion
        let elapsedSeconds = epoch.secondsSinceReferenceEpoch
            - body.rail.epoch.secondsSinceReferenceEpoch
        let reducedElapsedSeconds = elapsedSeconds.truncatingRemainder(dividingBy: period)
        return PlanarKeplerianRail.canonicalAngle(
            body.rail.longitudeOfPeriapsisRadians
                + body.rail.meanAnomalyAtEpochRadians
                + meanMotion * reducedElapsedSeconds
        )
    }

    private func polarAngle(of position: PlanarPosition) -> Double {
        PlanarKeplerianRail.canonicalAngle(
            atan2(position.meters.y, position.meters.x)
        )
    }

    private func anglesApproximatelyEqual(_ first: Double, _ second: Double) -> Bool {
        let forwardDifference = PlanarKeplerianRail.canonicalAngle(first - second)
        let shortestDifference = min(forwardDifference, 2 * Double.pi - forwardDifference)
        return shortestDifference <= HohmannTransferPlanner.maximumEpochRoundingPhaseErrorRadians
    }

    private func expectReferenceAlignment(
        for plan: HohmannTransferPlan,
        in system: GeneratedGravitySystem,
        departure: PlanarStateVector,
        arrival: PlanarStateVector
    ) throws {
        let sourceLongitudeAtDeparture = try circularReferenceLongitude(
            for: plan.sourceBodyID,
            in: system,
            at: plan.departureEpoch
        )
        let destinationLongitudeAtDeparture = try circularReferenceLongitude(
            for: plan.destinationBodyID,
            in: system,
            at: plan.departureEpoch
        )
        let destinationLongitudeAtArrival = try circularReferenceLongitude(
            for: plan.destinationBodyID,
            in: system,
            at: plan.arrivalEpoch
        )
        let actualDeparturePhase = PlanarKeplerianRail.canonicalAngle(
            destinationLongitudeAtDeparture - sourceLongitudeAtDeparture
        )
        let representedTransferPhase = plan.transferRail.meanMotionRadiansPerSecond
            * plan.transferDuration.seconds

        #expect(anglesApproximatelyEqual(polarAngle(of: departure.position), sourceLongitudeAtDeparture))
        #expect(anglesApproximatelyEqual(actualDeparturePhase, plan.requiredPhaseAngleRadians))
        #expect(anglesApproximatelyEqual(polarAngle(of: arrival.position), destinationLongitudeAtArrival))
        #expect(
            abs(representedTransferPhase - Double.pi)
                <= HohmannTransferPlanner.maximumEpochRoundingPhaseErrorRadians
        )
    }
}
