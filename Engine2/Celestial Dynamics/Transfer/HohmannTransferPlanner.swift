/// Produces the next prograde Hohmann opportunity for two generated planets.
///
/// Version one requires distinct planets orbiting the generated star. It uses
/// massless circular references at each planet's semimajor axis, while the
/// generated eccentric rails remain unchanged for ephemeris presentation.
nonisolated struct HohmannTransferPlanner: Sendable {
    private typealias PlanetPair = (source: GravityRailBody, destination: GravityRailBody)
    private typealias CircularReferenceTransfer = (
        sourceRadius: AstronomicalDistance,
        destinationRadius: AstronomicalDistance,
        primaryParameter: GravitationalParameter,
        sourceMeanMotion: Double,
        destinationMeanMotion: Double,
        transferSemiMajorAxis: AstronomicalDistance,
        transferEccentricity: OrbitalEccentricity,
        transferMeanMotion: Double,
        transferDuration: AstronomicalDuration,
        requiredPhase: Double
    )
    private typealias TransferOpportunity = (
        departureEpoch: CelestialEpoch,
        arrivalEpoch: CelestialEpoch,
        sourceLongitudeAtDeparture: Double
    )

    /// Maximum launch-window or transfer-phase error admitted after absolute-epoch rounding.
    static let maximumEpochRoundingPhaseErrorRadians = 1e-10

    /// Maximum relative error admitted when reconstructing either requested transfer apsis.
    static let maximumTransferApsisRelativeError = 1e-10

    let system: GeneratedGravitySystem

    private let bodiesByID: [GeneratedBodyID: GravityRailBody]

    init(system: GeneratedGravitySystem) throws(GravitySystemGenerationError) {
        try system.validate()
        self.system = system
        self.bodiesByID = Dictionary(
            uniqueKeysWithValues: system.bodies.map { ($0.id, $0) }
        )
    }

    /// Returns the first representable circular-reference transfer departing no earlier than the supplied epoch.
    func plan(
        from sourceBodyID: GeneratedBodyID,
        to destinationBodyID: GeneratedBodyID,
        noEarlierThan earliestDepartureEpoch: CelestialEpoch
    ) throws(HohmannTransferError) -> HohmannTransferPlan {
        let planets = try validatedPlanetPair(
            sourceBodyID: sourceBodyID,
            destinationBodyID: destinationBodyID
        )
        guard earliestDepartureEpoch >= system.epoch else {
            throw .departureBeforeReferenceEpoch
        }

        let referenceTransfer = try circularReferenceTransfer(for: planets)
        let opportunity = try nextTransferOpportunity(
            for: planets,
            referenceTransfer: referenceTransfer,
            noEarlierThan: earliestDepartureEpoch
        )
        let transferRail = try makeTransferRail(
            sourceRadiusMeters: referenceTransfer.sourceRadius.meters,
            destinationRadiusMeters: referenceTransfer.destinationRadius.meters,
            transferSemiMajorAxis: referenceTransfer.transferSemiMajorAxis,
            transferEccentricity: referenceTransfer.transferEccentricity,
            sourceLongitudeAtDeparture: opportunity.sourceLongitudeAtDeparture,
            departureEpoch: opportunity.departureEpoch,
            gravitationalParameter: referenceTransfer.primaryParameter
        )
        let deltaV = try deltaV(
            sourceRadiusMeters: referenceTransfer.sourceRadius.meters,
            destinationRadiusMeters: referenceTransfer.destinationRadius.meters,
            gravitationalParameter: referenceTransfer.primaryParameter
        )
        return HohmannTransferPlan(
            sourceBodyID: sourceBodyID,
            destinationBodyID: destinationBodyID,
            sourceReferenceRadius: referenceTransfer.sourceRadius,
            destinationReferenceRadius: referenceTransfer.destinationRadius,
            planningEpoch: earliestDepartureEpoch,
            departureEpoch: opportunity.departureEpoch,
            arrivalEpoch: opportunity.arrivalEpoch,
            requiredPhaseAngleRadians: referenceTransfer.requiredPhase,
            departureDeltaVMetersPerSecond: deltaV.departure,
            arrivalDeltaVMetersPerSecond: deltaV.arrival,
            transferRail: transferRail
        )
    }

    private func validatedPlanetPair(
        sourceBodyID: GeneratedBodyID,
        destinationBodyID: GeneratedBodyID
    ) throws(HohmannTransferError) -> PlanetPair {
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
        return (sourceBody, destinationBody)
    }

    private func circularReferenceTransfer(
        for planets: PlanetPair
    ) throws(HohmannTransferError) -> CircularReferenceTransfer {
        let sourceRadius = planets.source.rail.semiMajorAxis
        let destinationRadius = planets.destination.rail.semiMajorAxis
        guard sourceRadius != destinationRadius else {
            throw .coincidentReferenceOrbits
        }

        let primaryParameter = GravitationalParameter(
            primaryMass: system.starMass,
            orbitingMass: .zero
        )
        let transferSemiMajorAxis = try transferSemiMajorAxis(
            sourceRadiusMeters: sourceRadius.meters,
            destinationRadiusMeters: destinationRadius.meters
        )
        let transferEccentricity = try transferEccentricity(
            sourceRadiusMeters: sourceRadius.meters,
            destinationRadiusMeters: destinationRadius.meters,
            transferSemiMajorAxisMeters: transferSemiMajorAxis.meters
        )
        let sourceMeanMotion = try meanMotion(
            semiMajorAxisMeters: sourceRadius.meters,
            gravitationalParameter: primaryParameter
        )
        let destinationMeanMotion = try meanMotion(
            semiMajorAxisMeters: destinationRadius.meters,
            gravitationalParameter: primaryParameter
        )
        guard sourceMeanMotion != destinationMeanMotion else {
            throw .coincidentReferenceOrbits
        }

        let transferMeanMotion = try meanMotion(
            semiMajorAxisMeters: transferSemiMajorAxis.meters,
            gravitationalParameter: primaryParameter
        )
        let transferDuration = try transferDuration(meanMotion: transferMeanMotion)
        let requiredPhase = try requiredPhaseAngle(
            destinationMeanMotion: destinationMeanMotion,
            transferDuration: transferDuration
        )
        return (
            sourceRadius: sourceRadius,
            destinationRadius: destinationRadius,
            primaryParameter: primaryParameter,
            sourceMeanMotion: sourceMeanMotion,
            destinationMeanMotion: destinationMeanMotion,
            transferSemiMajorAxis: transferSemiMajorAxis,
            transferEccentricity: transferEccentricity,
            transferMeanMotion: transferMeanMotion,
            transferDuration: transferDuration,
            requiredPhase: requiredPhase
        )
    }

    private func nextTransferOpportunity(
        for planets: PlanetPair,
        referenceTransfer: CircularReferenceTransfer,
        noEarlierThan earliestDepartureEpoch: CelestialEpoch
    ) throws(HohmannTransferError) -> TransferOpportunity {
        let windowWait = try nextWindowWait(
            sourceBody: planets.source,
            destinationBody: planets.destination,
            at: earliestDepartureEpoch,
            sourceMeanMotion: referenceTransfer.sourceMeanMotion,
            destinationMeanMotion: referenceTransfer.destinationMeanMotion,
            requiredPhase: referenceTransfer.requiredPhase
        )
        let relativeAngularRate = referenceTransfer.destinationMeanMotion
            - referenceTransfer.sourceMeanMotion
        let departureEpoch = try departureEpoch(
            noEarlierThan: earliestDepartureEpoch,
            after: windowWait,
            relativeAngularRate: relativeAngularRate
        )
        let sourceLongitudeAtDeparture = referenceLongitude(
            for: planets.source,
            at: departureEpoch,
            meanMotion: referenceTransfer.sourceMeanMotion
        )
        try validateReferencePhaseAtDeparture(
            sourceLongitude: sourceLongitudeAtDeparture,
            destinationBody: planets.destination,
            departureEpoch: departureEpoch,
            destinationMeanMotion: referenceTransfer.destinationMeanMotion,
            requiredPhase: referenceTransfer.requiredPhase
        )
        let arrivalEpoch = try arrivalEpoch(
            departingAt: departureEpoch,
            after: referenceTransfer.transferDuration,
            transferMeanMotion: referenceTransfer.transferMeanMotion,
            destinationBody: planets.destination,
            destinationMeanMotion: referenceTransfer.destinationMeanMotion,
            transferEndpointLongitude: PlanarKeplerianRail.canonicalAngle(
                sourceLongitudeAtDeparture + Double.pi
            )
        )
        return (
            departureEpoch: departureEpoch,
            arrivalEpoch: arrivalEpoch,
            sourceLongitudeAtDeparture: sourceLongitudeAtDeparture
        )
    }

    private func departureEpoch(
        noEarlierThan earliestDepartureEpoch: CelestialEpoch,
        after windowWait: AstronomicalDuration,
        relativeAngularRate: Double
    ) throws(HohmannTransferError) -> CelestialEpoch {
        let advancement = try representedAdvancement(
            from: earliestDepartureEpoch,
            by: windowWait
        )
        let timingErrorSeconds = advancement.durationSeconds - windowWait.seconds
        let phaseError = abs(relativeAngularRate * timingErrorSeconds)
        guard phaseError.isFinite,
              phaseError <= Self.maximumEpochRoundingPhaseErrorRadians else {
            throw .unrepresentableTransfer
        }
        return advancement.epoch
    }

    private func arrivalEpoch(
        departingAt departureEpoch: CelestialEpoch,
        after transferDuration: AstronomicalDuration,
        transferMeanMotion: Double,
        destinationBody: GravityRailBody,
        destinationMeanMotion: Double,
        transferEndpointLongitude: Double
    ) throws(HohmannTransferError) -> CelestialEpoch {
        let advancement = try representedAdvancement(
            from: departureEpoch,
            by: transferDuration
        )
        let representedTransferPhase = transferMeanMotion * advancement.durationSeconds
        let phaseError = abs(representedTransferPhase - Double.pi)
        guard phaseError.isFinite,
              phaseError <= Self.maximumEpochRoundingPhaseErrorRadians else {
            throw .unrepresentableTransfer
        }
        let destinationLongitude = referenceLongitude(
            for: destinationBody,
            at: advancement.epoch,
            meanMotion: destinationMeanMotion
        )
        let destinationPhaseError = angularSeparation(
            destinationLongitude,
            transferEndpointLongitude
        )
        guard destinationPhaseError.isFinite,
              destinationPhaseError <= Self.maximumEpochRoundingPhaseErrorRadians else {
            throw .unrepresentableTransfer
        }
        return advancement.epoch
    }

    private func validateReferencePhaseAtDeparture(
        sourceLongitude: Double,
        destinationBody: GravityRailBody,
        departureEpoch: CelestialEpoch,
        destinationMeanMotion: Double,
        requiredPhase: Double
    ) throws(HohmannTransferError) {
        let destinationLongitude = referenceLongitude(
            for: destinationBody,
            at: departureEpoch,
            meanMotion: destinationMeanMotion
        )
        let actualPhase = PlanarKeplerianRail.canonicalAngle(
            destinationLongitude - sourceLongitude
        )
        let phaseError = angularSeparation(actualPhase, requiredPhase)
        guard phaseError.isFinite,
              phaseError <= Self.maximumEpochRoundingPhaseErrorRadians else {
            throw .unrepresentableTransfer
        }
    }

    private func transferSemiMajorAxis(
        sourceRadiusMeters: Double,
        destinationRadiusMeters: Double
    ) throws(HohmannTransferError) -> AstronomicalDistance {
        let meters = sourceRadiusMeters / 2 + destinationRadiusMeters / 2
        guard meters.isFinite, meters > 0 else {
            throw .unrepresentableTransfer
        }
        return AstronomicalDistance(meters: meters)
    }

    private func transferEccentricity(
        sourceRadiusMeters: Double,
        destinationRadiusMeters: Double,
        transferSemiMajorAxisMeters: Double
    ) throws(HohmannTransferError) -> OrbitalEccentricity {
        let largerRadius = max(sourceRadiusMeters, destinationRadiusMeters)
        let smallerRadius = min(sourceRadiusMeters, destinationRadiusMeters)
        let radiusRatio = smallerRadius / largerRadius
        let eccentricityValue = (1 - radiusRatio) / (1 + radiusRatio)
        guard eccentricityValue.isFinite,
              eccentricityValue > 0,
              eccentricityValue < 1 else {
            throw .unrepresentableTransfer
        }

        let reconstructedPeriapsis = transferSemiMajorAxisMeters * (1 - eccentricityValue)
        let reconstructedApoapsis = transferSemiMajorAxisMeters * (1 + eccentricityValue)
        let periapsisError = relativeError(reconstructedPeriapsis, comparedWith: smallerRadius)
        let apoapsisError = relativeError(reconstructedApoapsis, comparedWith: largerRadius)
        guard periapsisError.isFinite,
              periapsisError <= Self.maximumTransferApsisRelativeError,
              apoapsisError.isFinite,
              apoapsisError <= Self.maximumTransferApsisRelativeError else {
            throw .unrepresentableTransfer
        }
        return OrbitalEccentricity(rawValue: eccentricityValue)
    }

    private func meanMotion(
        semiMajorAxisMeters: Double,
        gravitationalParameter: GravitationalParameter
    ) throws(HohmannTransferError) -> Double {
        let parameter = gravitationalParameter.cubicMetersPerSecondSquared
        let meanMotion = (parameter / semiMajorAxisMeters).squareRoot() / semiMajorAxisMeters
        let orbitalPeriodSeconds = 2 * Double.pi / meanMotion
        guard meanMotion.isFinite,
              meanMotion > 0,
              orbitalPeriodSeconds.isFinite,
              orbitalPeriodSeconds > 0 else {
            throw .unrepresentableTransfer
        }
        return meanMotion
    }

    private func transferDuration(
        meanMotion: Double
    ) throws(HohmannTransferError) -> AstronomicalDuration {
        let seconds = Double.pi / meanMotion
        guard seconds.isFinite, seconds > 0 else {
            throw .unrepresentableTransfer
        }
        return AstronomicalDuration(seconds: seconds)
    }

    private func requiredPhaseAngle(
        destinationMeanMotion: Double,
        transferDuration: AstronomicalDuration
    ) throws(HohmannTransferError) -> Double {
        let destinationTravel = destinationMeanMotion * transferDuration.seconds
        guard destinationTravel.isFinite else {
            throw .unrepresentableTransfer
        }
        return PlanarKeplerianRail.canonicalAngle(Double.pi - destinationTravel)
    }

    private func nextWindowWait(
        sourceBody: GravityRailBody,
        destinationBody: GravityRailBody,
        at epoch: CelestialEpoch,
        sourceMeanMotion: Double,
        destinationMeanMotion: Double,
        requiredPhase: Double
    ) throws(HohmannTransferError) -> AstronomicalDuration {
        let currentSourceLongitude = referenceLongitude(
            for: sourceBody,
            at: epoch,
            meanMotion: sourceMeanMotion
        )
        let currentDestinationLongitude = referenceLongitude(
            for: destinationBody,
            at: epoch,
            meanMotion: destinationMeanMotion
        )
        let currentPhase = PlanarKeplerianRail.canonicalAngle(
            currentDestinationLongitude - currentSourceLongitude
        )
        let relativeAngularRate = destinationMeanMotion - sourceMeanMotion
        guard relativeAngularRate.isFinite, relativeAngularRate != 0 else {
            throw .coincidentReferenceOrbits
        }

        let phaseTravel: Double
        if relativeAngularRate > 0 {
            phaseTravel = PlanarKeplerianRail.canonicalAngle(requiredPhase - currentPhase)
        } else {
            phaseTravel = PlanarKeplerianRail.canonicalAngle(currentPhase - requiredPhase)
        }
        let waitSeconds = phaseTravel / abs(relativeAngularRate)
        guard waitSeconds.isFinite, waitSeconds >= 0 else {
            throw .unrepresentableTransfer
        }
        return AstronomicalDuration(seconds: waitSeconds)
    }

    private func referenceLongitude(
        for body: GravityRailBody,
        at epoch: CelestialEpoch,
        meanMotion: Double
    ) -> Double {
        let elapsedSeconds = epoch.secondsSinceReferenceEpoch
            - body.rail.epoch.secondsSinceReferenceEpoch
        let orbitalPeriodSeconds = 2 * Double.pi / meanMotion
        let reducedElapsedSeconds = elapsedSeconds.truncatingRemainder(
            dividingBy: orbitalPeriodSeconds
        )
        return PlanarKeplerianRail.canonicalAngle(
            body.rail.longitudeOfPeriapsisRadians
                + body.rail.meanAnomalyAtEpochRadians
                + meanMotion * reducedElapsedSeconds
        )
    }

    private func angularSeparation(_ first: Double, _ second: Double) -> Double {
        let forwardSeparation = PlanarKeplerianRail.canonicalAngle(first - second)
        return min(forwardSeparation, 2 * Double.pi - forwardSeparation)
    }

    private func relativeError(_ first: Double, comparedWith second: Double) -> Double {
        abs(first - second) / second
    }

    private func representedAdvancement(
        from epoch: CelestialEpoch,
        by duration: AstronomicalDuration
    ) throws(HohmannTransferError) -> (epoch: CelestialEpoch, durationSeconds: Double) {
        let seconds = epoch.secondsSinceReferenceEpoch + duration.seconds
        let preservesDirection = duration == .zero
            ? seconds == epoch.secondsSinceReferenceEpoch
            : seconds > epoch.secondsSinceReferenceEpoch
        let representedDuration = seconds - epoch.secondsSinceReferenceEpoch
        guard seconds.isFinite,
              preservesDirection,
              representedDuration.isFinite,
              representedDuration >= 0 else {
            throw .unrepresentableTransfer
        }
        return (
            epoch: CelestialEpoch(secondsSinceReferenceEpoch: seconds),
            durationSeconds: representedDuration
        )
    }

    private func makeTransferRail(
        sourceRadiusMeters: Double,
        destinationRadiusMeters: Double,
        transferSemiMajorAxis: AstronomicalDistance,
        transferEccentricity: OrbitalEccentricity,
        sourceLongitudeAtDeparture: Double,
        departureEpoch: CelestialEpoch,
        gravitationalParameter: GravitationalParameter
    ) throws(HohmannTransferError) -> PlanarKeplerianRail {
        let travelsOutward = destinationRadiusMeters > sourceRadiusMeters
        do {
            return try PlanarKeplerianRail(
                validatingSemiMajorAxis: transferSemiMajorAxis,
                eccentricity: transferEccentricity,
                longitudeOfPeriapsisRadians: travelsOutward
                    ? sourceLongitudeAtDeparture
                    : sourceLongitudeAtDeparture + Double.pi,
                meanAnomalyAtEpochRadians: travelsOutward ? 0 : Double.pi,
                epoch: departureEpoch,
                gravitationalParameter: gravitationalParameter
            )
        } catch {
            throw .unrepresentableTransfer
        }
    }

    private func deltaV(
        sourceRadiusMeters: Double,
        destinationRadiusMeters: Double,
        gravitationalParameter: GravitationalParameter
    ) throws(HohmannTransferError) -> (departure: Double, arrival: Double) {
        let parameterSquareRoot = gravitationalParameter.cubicMetersPerSecondSquared.squareRoot()
        let sourceCircularSpeed = parameterSquareRoot / sourceRadiusMeters.squareRoot()
        let destinationCircularSpeed = parameterSquareRoot / destinationRadiusMeters.squareRoot()

        let radiusScale = max(sourceRadiusMeters, destinationRadiusMeters)
        let normalizedSourceRadius = sourceRadiusMeters / radiusScale
        let normalizedDestinationRadius = destinationRadiusMeters / radiusScale
        let normalizedRadiusSum = normalizedSourceRadius + normalizedDestinationRadius
        let sourceTransferSpeed = sourceCircularSpeed
            * (2 * normalizedDestinationRadius / normalizedRadiusSum).squareRoot()
        let destinationTransferSpeed = destinationCircularSpeed
            * (2 * normalizedSourceRadius / normalizedRadiusSum).squareRoot()
        let departure = abs(sourceTransferSpeed - sourceCircularSpeed)
        let arrival = abs(destinationCircularSpeed - destinationTransferSpeed)
        let total = departure + arrival
        guard parameterSquareRoot.isFinite,
              parameterSquareRoot > 0,
              sourceCircularSpeed.isFinite,
              sourceCircularSpeed > 0,
              destinationCircularSpeed.isFinite,
              destinationCircularSpeed > 0,
              sourceTransferSpeed.isFinite,
              sourceTransferSpeed > 0,
              destinationTransferSpeed.isFinite,
              destinationTransferSpeed > 0,
              departure.isFinite,
              departure >= 0,
              arrival.isFinite,
              arrival >= 0,
              total.isFinite,
              total > 0 else {
            throw .unrepresentableTransfer
        }
        return (departure, arrival)
    }
}
