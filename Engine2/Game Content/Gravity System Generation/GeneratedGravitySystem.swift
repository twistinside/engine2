/// Immutable planar rail projection of one validated generated star system.
///
/// The value retains every resolved planet and significant moon. Planet rails
/// are star-relative, moon rails are parent-relative, and every body carries a
/// complete orientation and phase at the common reference epoch. Structural
/// validation establishes safe hierarchy and gravity inputs after decoding.
nonisolated struct GeneratedGravitySystem: Codable, Equatable, Sendable {
    let seed: StarSystemSeed
    let modelVersion: CelestialDynamicsModelVersion
    let epoch: CelestialEpoch
    let starMass: AstronomicalMass
    let starRadius: AstronomicalDistance
    let bodies: [GravityRailBody]

    /// Rejects invalid persisted values before ephemeris or force evaluation.
    func validate() throws(GravitySystemGenerationError) {
        guard modelVersion == .planarKeplerV1 else {
            throw .unsupportedDynamicsModel(modelVersion)
        }
        try validateSystemRoot()
        guard bodies == bodies.sorted(by: { $0.id < $1.id }) else {
            throw .bodiesNotOrdered
        }

        var identities: Set<GeneratedBodyID> = []
        for body in bodies {
            guard identities.insert(body.id).inserted else {
                throw .duplicateBodyID(body.id)
            }
            guard isValid(body) else {
                throw .invalidBody(body.id)
            }
            guard hasExpectedDerivedPhase(body) else {
                throw .inconsistentPhase(body.id)
            }
        }
        try validateHierarchyClearanceAndGravitationalParameters()
    }

    private func validateSystemRoot() throws(GravitySystemGenerationError) {
        let starParameter = GravitationalParameter
            .newtonianGravitationalConstantCubicMetersPerKilogramSecondSquared
            * starMass.kilograms
        guard epoch.secondsSinceReferenceEpoch.isFinite,
              epoch.secondsSinceReferenceEpoch >= 0,
              starMass.kilograms.isFinite,
              starMass.kilograms > 0,
              starRadius.meters.isFinite,
              starRadius.meters > 0,
              starParameter.isFinite,
              starParameter > 0 else {
            throw .invalidStar
        }
    }

    private func validateHierarchyClearanceAndGravitationalParameters() throws(GravitySystemGenerationError) {
        let bodiesByID = Dictionary(uniqueKeysWithValues: bodies.map { ($0.id, $0) })
        for body in bodies {
            let primaryMass: AstronomicalMass
            let primaryRadius: AstronomicalDistance
            if let parentID = body.parentID {
                guard let parent = bodiesByID[parentID] else {
                    throw .missingParent(body: body.id, parent: parentID)
                }
                guard body.id.parentPlanetID == parentID,
                      parent.id.isPlanet,
                      parent.parentID == nil else {
                    throw .invalidBody(body.id)
                }
                primaryMass = parent.mass
                primaryRadius = parent.radius
            } else {
                guard body.id.isPlanet else {
                    throw .invalidBody(body.id)
                }
                primaryMass = starMass
                primaryRadius = starRadius
            }

            let periapsisMeters = body.rail.semiMajorAxis.meters
                * (1 - body.rail.eccentricity.rawValue)
            let combinedRadiiMeters = primaryRadius.meters + body.radius.meters
            guard periapsisMeters > combinedRadiiMeters else {
                throw .periapsisIntersectsPrimary(
                    body: body.id,
                    primaryBodyID: body.parentID
                )
            }

            let totalMassKilograms = primaryMass.kilograms + body.mass.kilograms
            let expectedParameter = GravitationalParameter
                .newtonianGravitationalConstantCubicMetersPerKilogramSecondSquared
                * totalMassKilograms
            guard totalMassKilograms.isFinite,
                  expectedParameter.isFinite,
                  expectedParameter > 0 else {
                throw .invalidBody(body.id)
            }
            guard approximatelyEqual(
                body.rail.gravitationalParameter.cubicMetersPerSecondSquared,
                expectedParameter
            ) else {
                throw .inconsistentGravitationalParameter(body.id)
            }
        }
    }

    private func isValid(_ body: GravityRailBody) -> Bool {
        let rail = body.rail
        let standaloneParameter = GravitationalParameter
            .newtonianGravitationalConstantCubicMetersPerKilogramSecondSquared
            * body.mass.kilograms
        guard body.mass.kilograms.isFinite,
              body.mass.kilograms > 0,
              standaloneParameter.isFinite,
              standaloneParameter > 0,
              body.radius.meters.isFinite,
              body.radius.meters > 0,
              rail.epoch == epoch,
              rail.isValidForPropagation else {
            return false
        }
        return rail.longitudeOfPeriapsisRadians
                == PlanarKeplerianRail.canonicalAngle(rail.longitudeOfPeriapsisRadians)
            && rail.meanAnomalyAtEpochRadians
                == PlanarKeplerianRail.canonicalAngle(rail.meanAnomalyAtEpochRadians)
    }

    private func hasExpectedDerivedPhase(_ body: GravityRailBody) -> Bool {
        body.rail.longitudeOfPeriapsisRadians == GravitySystemGenerator.phase(
            seed: seed,
            modelVersion: modelVersion,
            bodyID: body.id,
            domain: .longitudeOfPeriapsis
        )
            && body.rail.meanAnomalyAtEpochRadians == GravitySystemGenerator.phase(
                seed: seed,
                modelVersion: modelVersion,
                bodyID: body.id,
                domain: .meanAnomalyAtEpoch
            )
    }

    private func approximatelyEqual(_ first: Double, _ second: Double) -> Bool {
        let scale = max(abs(first), abs(second))
        return abs(first - second) <= scale * 1e-12
    }
}
