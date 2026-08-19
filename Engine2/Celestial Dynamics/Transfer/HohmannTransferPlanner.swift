/// Produces the next prograde Hohmann opportunity for two generated planets.
///
/// Version one requires distinct planets orbiting the generated star. It uses
/// massless circular references at each planet's semimajor axis, while the
/// generated eccentric rails remain unchanged for ephemeris presentation.
nonisolated struct HohmannTransferPlanner: Sendable {
    let system: GeneratedGravitySystem

    private let bodiesByID: [GeneratedBodyID: GravityRailBody]

    init(system: GeneratedGravitySystem) throws(GravitySystemGenerationError) {
        try system.validate()
        self.system = system
        self.bodiesByID = Dictionary(
            uniqueKeysWithValues: system.bodies.map { ($0.id, $0) }
        )
    }

    /// Returns the first circular-reference transfer departing no earlier than the supplied epoch.
    func plan(
        from sourceBodyID: GeneratedBodyID,
        to destinationBodyID: GeneratedBodyID,
        noEarlierThan earliestDepartureEpoch: CelestialEpoch
    ) throws(HohmannTransferError) -> HohmannTransferPlan {
        guard sourceBodyID != destinationBodyID else {
            throw .identicalBodies(sourceBodyID)
        }
        guard let sourceBody = bodiesByID[sourceBodyID] else {
            throw .unknownBody(sourceBodyID)
        }
        guard let destinationBody = bodiesByID[destinationBodyID] else {
            throw .unknownBody(destinationBodyID)
        }
        guard sourceBody.id.isPlanet, sourceBody.parentID == nil else {
            throw .requiresPlanet(sourceBodyID)
        }
        guard destinationBody.id.isPlanet, destinationBody.parentID == nil else {
            throw .requiresPlanet(destinationBodyID)
        }
        guard earliestDepartureEpoch >= system.epoch else {
            throw .departureBeforeReferenceEpoch
        }

        let sourceRadiusMeters = sourceBody.rail.semiMajorAxis.meters
        let destinationRadiusMeters = destinationBody.rail.semiMajorAxis.meters
        guard sourceRadiusMeters != destinationRadiusMeters else {
            throw .coincidentReferenceOrbits
        }

        let primaryParameter = GravitationalParameter(
            primaryMass: system.starMass,
            orbitingMass: .zero
        )
        let parameter = primaryParameter.cubicMetersPerSecondSquared
        let transferSemiMajorAxisMeters = (sourceRadiusMeters + destinationRadiusMeters) / 2
        let transferMeanMotion = meanMotion(
            radiusMeters: transferSemiMajorAxisMeters,
            gravitationalParameter: parameter
        )
        let transferDuration = AstronomicalDuration(
            seconds: Double.pi / transferMeanMotion
        )
        let sourceMeanMotion = meanMotion(
            radiusMeters: sourceRadiusMeters,
            gravitationalParameter: parameter
        )
        let destinationMeanMotion = meanMotion(
            radiusMeters: destinationRadiusMeters,
            gravitationalParameter: parameter
        )
        let requiredPhase = PlanarKeplerianRail.canonicalAngle(
            Double.pi - destinationMeanMotion * transferDuration.seconds
        )
        let currentSourceLongitude = referenceLongitude(
            for: sourceBody,
            at: earliestDepartureEpoch,
            meanMotion: sourceMeanMotion
        )
        let currentDestinationLongitude = referenceLongitude(
            for: destinationBody,
            at: earliestDepartureEpoch,
            meanMotion: destinationMeanMotion
        )
        let currentPhase = PlanarKeplerianRail.canonicalAngle(
            currentDestinationLongitude - currentSourceLongitude
        )
        let windowWait = nextWindowWait(
            currentPhase: currentPhase,
            requiredPhase: requiredPhase,
            relativeAngularRate: destinationMeanMotion - sourceMeanMotion
        )
        let departureEpoch = earliestDepartureEpoch.advanced(by: windowWait)
        let arrivalEpoch = departureEpoch.advanced(by: transferDuration)
        let sourceLongitudeAtDeparture = referenceLongitude(
            for: sourceBody,
            at: departureEpoch,
            meanMotion: sourceMeanMotion
        )
        let transferRail = makeTransferRail(
            sourceRadiusMeters: sourceRadiusMeters,
            destinationRadiusMeters: destinationRadiusMeters,
            transferSemiMajorAxisMeters: transferSemiMajorAxisMeters,
            sourceLongitudeAtDeparture: sourceLongitudeAtDeparture,
            departureEpoch: departureEpoch,
            gravitationalParameter: primaryParameter
        )
        let deltaV = deltaV(
            sourceRadiusMeters: sourceRadiusMeters,
            destinationRadiusMeters: destinationRadiusMeters,
            transferSemiMajorAxisMeters: transferSemiMajorAxisMeters,
            gravitationalParameter: parameter
        )
        return HohmannTransferPlan(
            sourceBodyID: sourceBodyID,
            destinationBodyID: destinationBodyID,
            primaryBodyID: sourceBody.parentID,
            sourceReferenceRadius: sourceBody.rail.semiMajorAxis,
            destinationReferenceRadius: destinationBody.rail.semiMajorAxis,
            nextWindowWait: windowWait,
            departureEpoch: departureEpoch,
            arrivalEpoch: arrivalEpoch,
            transferDuration: transferDuration,
            requiredPhaseAngleRadians: requiredPhase,
            departureDeltaVMetersPerSecond: deltaV.departure,
            arrivalDeltaVMetersPerSecond: deltaV.arrival,
            totalDeltaVMetersPerSecond: deltaV.departure + deltaV.arrival,
            transferRail: transferRail
        )
    }

    private func meanMotion(
        radiusMeters: Double,
        gravitationalParameter: Double
    ) -> Double {
        (gravitationalParameter / radiusMeters).squareRoot() / radiusMeters
    }

    private func referenceLongitude(
        for body: GravityRailBody,
        at epoch: CelestialEpoch,
        meanMotion: Double
    ) -> Double {
        let elapsedSeconds = epoch.secondsSinceReferenceEpoch
            - body.rail.epoch.secondsSinceReferenceEpoch
        let reducedElapsedSeconds = elapsedSeconds.truncatingRemainder(
            dividingBy: 2 * Double.pi / meanMotion
        )
        return PlanarKeplerianRail.canonicalAngle(
            body.rail.longitudeOfPeriapsisRadians
                + body.rail.meanAnomalyAtEpochRadians
                + meanMotion * reducedElapsedSeconds
        )
    }

    private func nextWindowWait(
        currentPhase: Double,
        requiredPhase: Double,
        relativeAngularRate: Double
    ) -> AstronomicalDuration {
        let phaseTravel: Double
        if relativeAngularRate > 0 {
            phaseTravel = PlanarKeplerianRail.canonicalAngle(requiredPhase - currentPhase)
        } else {
            phaseTravel = PlanarKeplerianRail.canonicalAngle(currentPhase - requiredPhase)
        }
        return AstronomicalDuration(seconds: phaseTravel / abs(relativeAngularRate))
    }

    private func makeTransferRail(
        sourceRadiusMeters: Double,
        destinationRadiusMeters: Double,
        transferSemiMajorAxisMeters: Double,
        sourceLongitudeAtDeparture: Double,
        departureEpoch: CelestialEpoch,
        gravitationalParameter: GravitationalParameter
    ) -> PlanarKeplerianRail {
        let eccentricity = abs(destinationRadiusMeters - sourceRadiusMeters)
            / (sourceRadiusMeters + destinationRadiusMeters)
        let travelsOutward = destinationRadiusMeters > sourceRadiusMeters
        return PlanarKeplerianRail(
            semiMajorAxis: AstronomicalDistance(meters: transferSemiMajorAxisMeters),
            eccentricity: OrbitalEccentricity(rawValue: eccentricity),
            longitudeOfPeriapsisRadians: travelsOutward
                ? sourceLongitudeAtDeparture
                : sourceLongitudeAtDeparture + Double.pi,
            meanAnomalyAtEpochRadians: travelsOutward ? 0 : Double.pi,
            epoch: departureEpoch,
            gravitationalParameter: gravitationalParameter
        )
    }

    private func deltaV(
        sourceRadiusMeters: Double,
        destinationRadiusMeters: Double,
        transferSemiMajorAxisMeters: Double,
        gravitationalParameter: Double
    ) -> (departure: Double, arrival: Double) {
        let sourceCircularSpeed = (gravitationalParameter / sourceRadiusMeters).squareRoot()
        let destinationCircularSpeed = (gravitationalParameter / destinationRadiusMeters).squareRoot()
        let sourceTransferSpeed = (
            gravitationalParameter
                * (2 / sourceRadiusMeters - 1 / transferSemiMajorAxisMeters)
        ).squareRoot()
        let destinationTransferSpeed = (
            gravitationalParameter
                * (2 / destinationRadiusMeters - 1 / transferSemiMajorAxisMeters)
        ).squareRoot()
        return (
            departure: abs(sourceTransferSpeed - sourceCircularSpeed),
            arrival: abs(destinationCircularSpeed - destinationTransferSpeed)
        )
    }
}
