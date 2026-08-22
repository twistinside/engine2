/// Complete bound prograde orbit in one shared two-dimensional plane.
///
/// The rail stores orientation and phase at an explicit epoch, which lets one
/// propagation kernel reproduce position and velocity without mutable history.
/// Angles are canonical radians in `0..<2π`.
nonisolated struct PlanarKeplerianRail: Equatable, Sendable {
    let semiMajorAxis: AstronomicalDistance
    let eccentricity: OrbitalEccentricity
    let longitudeOfPeriapsisRadians: Double
    let meanAnomalyAtEpochRadians: Double
    let epoch: CelestialEpoch
    let gravitationalParameter: GravitationalParameter

    var meanMotionRadiansPerSecond: Double {
        let axis = semiMajorAxis.meters
        return (
            gravitationalParameter.cubicMetersPerSecondSquared / axis
        ).squareRoot() / axis
    }

    var orbitalPeriod: AstronomicalDuration {
        AstronomicalDuration(
            seconds: 2 * Double.pi / meanMotionRadiansPerSecond
        )
    }

    /// Whether every stored and derived value required by propagation is representable.
    var isValidForPropagation: Bool {
        Self.validationError(
            semiMajorAxis: semiMajorAxis,
            eccentricity: eccentricity,
            longitudeOfPeriapsisRadians: longitudeOfPeriapsisRadians,
            meanAnomalyAtEpochRadians: meanAnomalyAtEpochRadians,
            epoch: epoch,
            gravitationalParameter: gravitationalParameter
        ) == nil
    }

    init(
        semiMajorAxis: AstronomicalDistance,
        eccentricity: OrbitalEccentricity,
        longitudeOfPeriapsisRadians: Double,
        meanAnomalyAtEpochRadians: Double,
        epoch: CelestialEpoch,
        gravitationalParameter: GravitationalParameter
    ) {
        let rail: Self
        do {
            rail = try Self(
                validatingSemiMajorAxis: semiMajorAxis,
                eccentricity: eccentricity,
                longitudeOfPeriapsisRadians: longitudeOfPeriapsisRadians,
                meanAnomalyAtEpochRadians: meanAnomalyAtEpochRadians,
                epoch: epoch,
                gravitationalParameter: gravitationalParameter
            )
        } catch {
            preconditionFailure(error.message)
        }
        self = rail
    }

    /// Constructs a rail only when its propagation inputs and derived cadence are representable.
    init(
        validatingSemiMajorAxis semiMajorAxis: AstronomicalDistance,
        eccentricity: OrbitalEccentricity,
        longitudeOfPeriapsisRadians: Double,
        meanAnomalyAtEpochRadians: Double,
        epoch: CelestialEpoch,
        gravitationalParameter: GravitationalParameter
    ) throws(PlanarKeplerianRailValidationError) {
        if let error = Self.validationError(
            semiMajorAxis: semiMajorAxis,
            eccentricity: eccentricity,
            longitudeOfPeriapsisRadians: longitudeOfPeriapsisRadians,
            meanAnomalyAtEpochRadians: meanAnomalyAtEpochRadians,
            epoch: epoch,
            gravitationalParameter: gravitationalParameter
        ) {
            throw error
        }
        self.semiMajorAxis = semiMajorAxis
        self.eccentricity = eccentricity
        self.longitudeOfPeriapsisRadians = Self.canonicalAngle(longitudeOfPeriapsisRadians)
        self.meanAnomalyAtEpochRadians = Self.canonicalAngle(meanAnomalyAtEpochRadians)
        self.epoch = epoch
        self.gravitationalParameter = gravitationalParameter
    }

    /// Returns one finite angle in the canonical `0..<2π` interval.
    static func canonicalAngle(_ radians: Double) -> Double {
        precondition(radians.isFinite, "An orbital angle must be finite.")
        let fullTurn = 2 * Double.pi
        let remainder = radians.truncatingRemainder(dividingBy: fullTurn)
        let canonical = remainder < 0 ? remainder + fullTurn : remainder
        return canonical == 0 || canonical >= fullTurn ? 0 : canonical
    }

    private static func validationError(
        semiMajorAxis: AstronomicalDistance,
        eccentricity: OrbitalEccentricity,
        longitudeOfPeriapsisRadians: Double,
        meanAnomalyAtEpochRadians: Double,
        epoch: CelestialEpoch,
        gravitationalParameter: GravitationalParameter
    ) -> PlanarKeplerianRailValidationError? {
        let semiMajorAxisMeters = semiMajorAxis.meters
        guard semiMajorAxisMeters.isFinite, semiMajorAxisMeters > 0 else {
            return .invalidSemiMajorAxis
        }
        guard eccentricity.rawValue.isFinite, (0..<1).contains(eccentricity.rawValue) else {
            return .invalidEccentricity
        }
        guard longitudeOfPeriapsisRadians.isFinite else {
            return .invalidLongitudeOfPeriapsis
        }
        guard meanAnomalyAtEpochRadians.isFinite else {
            return .invalidMeanAnomalyAtEpoch
        }
        guard epoch.secondsSinceReferenceEpoch.isFinite, epoch.secondsSinceReferenceEpoch >= 0 else {
            return .invalidEpoch
        }

        let parameter = gravitationalParameter.cubicMetersPerSecondSquared
        guard parameter.isFinite, parameter > 0 else {
            return .invalidGravitationalParameter
        }
        let meanMotion = (parameter / semiMajorAxisMeters).squareRoot() / semiMajorAxisMeters
        guard meanMotion.isFinite, meanMotion > 0 else {
            return .unrepresentableMeanMotion
        }
        let orbitalPeriodSeconds = 2 * Double.pi / meanMotion
        guard orbitalPeriodSeconds.isFinite, orbitalPeriodSeconds > 0 else {
            return .unrepresentableOrbitalPeriod
        }
        return nil
    }
}

extension PlanarKeplerianRail: Codable {
    private enum CodingKeys: String, CodingKey {
        case semiMajorAxis
        case eccentricity
        case longitudeOfPeriapsisRadians
        case meanAnomalyAtEpochRadians
        case epoch
        case gravitationalParameter
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let semiMajorAxis = try container.decode(AstronomicalDistance.self, forKey: .semiMajorAxis)
        let eccentricity = try container.decode(OrbitalEccentricity.self, forKey: .eccentricity)
        let longitudeOfPeriapsisRadians = try container.decode(Double.self, forKey: .longitudeOfPeriapsisRadians)
        let meanAnomalyAtEpochRadians = try container.decode(Double.self, forKey: .meanAnomalyAtEpochRadians)
        let epoch = try container.decode(CelestialEpoch.self, forKey: .epoch)
        let gravitationalParameter = try container.decode(
            GravitationalParameter.self,
            forKey: .gravitationalParameter
        )

        let rail: Self
        do {
            rail = try Self(
                validatingSemiMajorAxis: semiMajorAxis,
                eccentricity: eccentricity,
                longitudeOfPeriapsisRadians: longitudeOfPeriapsisRadians,
                meanAnomalyAtEpochRadians: meanAnomalyAtEpochRadians,
                epoch: epoch,
                gravitationalParameter: gravitationalParameter
            )
        } catch {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: error.message
                )
            )
        }
        guard rail.longitudeOfPeriapsisRadians == longitudeOfPeriapsisRadians,
              rail.meanAnomalyAtEpochRadians == meanAnomalyAtEpochRadians else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Persisted orbital angles must use canonical radians in 0..<2π."
                )
            )
        }
        self = rail
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(semiMajorAxis, forKey: .semiMajorAxis)
        try container.encode(eccentricity, forKey: .eccentricity)
        try container.encode(longitudeOfPeriapsisRadians, forKey: .longitudeOfPeriapsisRadians)
        try container.encode(meanAnomalyAtEpochRadians, forKey: .meanAnomalyAtEpochRadians)
        try container.encode(epoch, forKey: .epoch)
        try container.encode(gravitationalParameter, forKey: .gravitationalParameter)
    }
}
