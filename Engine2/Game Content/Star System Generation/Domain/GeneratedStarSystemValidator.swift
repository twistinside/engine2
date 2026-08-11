import Foundation

/// Validates one persisted generated system against its model inputs and physical invariants.
///
/// The validator replays deterministic stellar, disk, and environmental derivations before
/// checking body identities, orbital stability, satellite bounds, dynamical destinations,
/// ancestry closure, and conserved mass ledgers.
nonisolated struct GeneratedStarSystemValidator: Sendable {
    private static let planetaryOrbitalSlack = 1e-10
    private static let moonOrbitalSlackMeters = 1e-6

    private let seed: StarSystemSeed
    private let modelVersion: StarSystemGenerationModelVersion
    private let policy: StarSystemGenerationPolicy
    private let star: GeneratedStar
    private let protoplanetaryDisk: GeneratedProtoplanetaryDisk
    private let formationLedger: StarSystemFormationLedger
    private let planets: [GeneratedPlanet]

    private var allCompositions: [CelestialMassComposition] {
        planets.flatMap { planet in
            [planet.composition] + planet.moons.map(\.composition)
        }
    }

    init(system: GeneratedStarSystem) {
        seed = system.seed
        modelVersion = system.modelVersion
        policy = system.policy
        star = system.star
        protoplanetaryDisk = system.protoplanetaryDisk
        formationLedger = system.formationLedger
        planets = system.planets
    }

    /// Replays deterministic facts and rejects the first violated invariant in canonical order.
    func validate() throws(StarSystemGenerationError) {
        try validateModelAndStar()
        try validateDisk()
        try validateBodiesAndIdentities()
        try validateDerivedBodyFacts()
        try validatePlanetaryArchitecture()
        try validateMoonArchitectures()
        try validateMassLedgers()
    }

    private func validateModelAndStar() throws(StarSystemGenerationError) {
        guard modelVersion == policy.modelVersion else {
            throw .inconsistentModelVersion
        }
        guard policy.isValid, policy.isSupportedCalibration else {
            throw .invalidPolicy
        }
        guard star.mass.kilograms.isFinite,
              star.mass.kilograms > 0,
              star.metallicityDex.isFinite,
              star.age.seconds.isFinite,
              star.age.seconds > 0,
              star.luminosity.watts.isFinite,
              star.luminosity.watts > 0,
              star.radius.meters.isFinite,
              star.radius.meters > 0,
              star.effectiveTemperature.kelvin.isFinite,
              star.effectiveTemperature.kelvin > 0,
              star.xuvLuminosityFraction.isFinite,
              star.xuvLuminosityFraction >= 0,
              star.xuvLuminosityFraction <= 1,
              (policy.minimumStellarMassSolar...policy.maximumStellarMassSolar)
                .contains(star.mass.solarMasses),
              (policy.minimumMetallicityDex...policy.maximumMetallicityDex)
                .contains(star.metallicityDex),
              (policy.minimumSystemAgeGigayears...policy.maximumSystemAgeGigayears)
                .contains(star.age.gigayears) else {
            throw .invalidStar
        }
        let expectedStar = MainSequenceStarGenerator(policy: policy).generate(seed: seed)
        guard starsApproximatelyEqual(star, expectedStar) else {
            throw .invalidStar
        }
    }

    private func validateDisk() throws(StarSystemGenerationError) {
        let disk = protoplanetaryDisk
        guard disk.initialGasMass.kilograms.isFinite,
              disk.initialGasMass.kilograms > 0,
              disk.initialSolidMass.kilograms.isFinite,
              disk.initialSolidMass.kilograms > 0,
              isValidComposition(disk.initialSolidComposition),
              disk.initialSolidComposition.hydrogenHelium == .zero,
              approximatelyEqual(
                  disk.initialSolidMass.kilograms,
                  solidMassKilograms(in: disk.initialSolidComposition)
              ),
              disk.lifetime.seconds.isFinite,
              disk.lifetime.seconds > 0,
              disk.innerEdge.meters > star.radius.meters,
              disk.outerEdge > disk.innerEdge,
              disk.characteristicRadius.meters > 0,
              disk.surfaceDensityExponent.isFinite,
              disk.waterSnowLine.meters > 0,
              disk.annulusCount == policy.annulusCount else {
            throw .invalidDisk
        }
        let expectedStar = MainSequenceStarGenerator(policy: policy).generate(seed: seed)
        let expectedDisk = ProtoplanetaryDiskGenerator(policy: policy).generate(
            around: expectedStar,
            seed: seed
        ).summary
        guard disksApproximatelyEqual(disk, expectedDisk) else {
            throw .invalidDisk
        }
    }

    private func validateBodiesAndIdentities() throws(StarSystemGenerationError) {
        guard !planets.isEmpty, planets.count <= policy.maximumEmbryoCount else {
            throw .noFundedEmbryos
        }
        var identities: Set<GeneratedBodyID> = []
        var containsSubthresholdPlanet = false
        for planet in planets {
            guard isPlanetIdentity(planet.id) else {
                throw .invalidPlanet(planet.id)
            }
            guard identities.insert(planet.id).inserted else {
                throw .duplicateBodyID(planet.id)
            }
            guard isValidPlanet(planet) else {
                throw .invalidPlanet(planet.id)
            }
            guard planet.moons.count <= policy.maximumMoonCountPerPlanet else {
                throw .invalidPlanet(planet.id)
            }
            for moon in planet.moons {
                guard isMoonIdentity(moon.id, parent: planet.id) else {
                    throw .invalidMoon(moon.id)
                }
                guard identities.insert(moon.id).inserted else {
                    throw .duplicateBodyID(moon.id)
                }
                guard isValidMoon(moon), moon.mass < planet.mass else {
                    throw .invalidMoon(moon.id)
                }
            }
            let planetarySystemSolidMassEarth = planet.composition.solidMass.earthMasses
                + planet.moons.reduce(0) { $0 + $1.composition.solidMass.earthMasses }
            containsSubthresholdPlanet = containsSubthresholdPlanet
                || planetarySystemSolidMassEarth
                    < policy.minimumResolvedPlanetSolidMassEarth
        }
        guard planets.count == 1 || !containsSubthresholdPlanet else {
            throw .invalidFormationLedger
        }
    }

    private func validateDerivedBodyFacts() throws(StarSystemGenerationError) {
        let resolver = PlanetaryEnvironmentResolver(policy: policy)
        for planet in planets {
            let expectedPlanet = resolver.resolvePresentBody(
                composition: planet.composition,
                orbit: planet.orbit,
                around: star
            )
            guard approximatelyEqual(expectedPlanet.radius.meters, planet.radius.meters),
                  environmentsApproximatelyEqual(expectedPlanet.environment, planet.environment),
                  expectedPlanet.physicalState == planet.physicalState else {
                throw .inconsistentDerivedBody(planet.id)
            }
            for moon in planet.moons {
                let expectedMoon = resolver.resolvePresentBody(
                    composition: moon.composition,
                    orbit: planet.orbit,
                    around: star
                )
                guard approximatelyEqual(expectedMoon.radius.meters, moon.radius.meters),
                      environmentsApproximatelyEqual(expectedMoon.environment, moon.environment),
                      expectedMoon.physicalState == moon.physicalState else {
                    throw .inconsistentDerivedBody(moon.id)
                }
            }
        }
    }

    private func validatePlanetaryArchitecture() throws(StarSystemGenerationError) {
        guard planets == planets.sorted(by: { $0.orbit.semiMajorAxis < $1.orbit.semiMajorAxis }) else {
            throw .planetsNotOrdered
        }
        guard planets.count > 1 else {
            return
        }
        for index in 0..<(planets.count - 1) {
            let inner = planets[index]
            let outer = planets[index + 1]
            let requiredSpacing = policy.requiredFinalSpacing(
                between: inner.mass,
                and: outer.mass
            )
            let clearance = inner.orbitalClearance(to: outer, around: star.mass)
            guard clearance.mutualHillSpacing + Self.planetaryOrbitalSlack >= requiredSpacing,
                  policy.acceptsRadialClearance(
                      clearance,
                      additiveSlack: Self.planetaryOrbitalSlack
                  ) else {
                throw .unstablePlanetPair(inner: inner.id, outer: outer.id)
            }
        }
    }

    private func validateMoonArchitectures() throws(StarSystemGenerationError) {
        let environmentResolver = PlanetaryEnvironmentResolver(policy: policy)
        let moonGenerator = MoonSystemGenerator(
            policy: policy,
            environmentResolver: environmentResolver
        )
        for planet in planets {
            let parentBody = environmentResolver.resolvePresentBody(
                composition: planet.composition,
                orbit: planet.orbit,
                around: star
            )
            guard planet.moons == planet.moons.sorted(by: {
                $0.orbit.semiMajorAxis < $1.orbit.semiMajorAxis
            }) else {
                throw .invalidPlanet(planet.id)
            }
            for moon in planet.moons {
                let moonBody = environmentResolver.resolvePresentBody(
                    composition: moon.composition,
                    orbit: planet.orbit,
                    around: star
                )
                let expectedBounds = moonGenerator.satelliteStableBounds(
                    parent: parentBody,
                    moon: moonBody,
                    parentOrbit: planet.orbit,
                    moonEccentricity: moon.orbit.eccentricity.rawValue,
                    star: star
                )
                guard approximatelyEqual(
                    moon.minimumStableOrbit.meters,
                    expectedBounds.minimum.meters
                ),
                approximatelyEqual(
                    moon.maximumStableOrbit.meters,
                    expectedBounds.maximum.meters
                ),
                moon.orbit.semiMajorAxis.meters + Self.moonOrbitalSlackMeters
                    >= expectedBounds.minimum.meters,
                moon.orbit.semiMajorAxis.meters - Self.moonOrbitalSlackMeters
                    <= expectedBounds.maximum.meters else {
                    throw .invalidMoon(moon.id)
                }
            }
            try validateMoonPairClearance(for: planet)
        }
    }

    private func validateMoonPairClearance(
        for planet: GeneratedPlanet
    ) throws(StarSystemGenerationError) {
        guard planet.moons.count > 1 else {
            return
        }
        for index in 0..<(planet.moons.count - 1) {
            let inner = planet.moons[index]
            let outer = planet.moons[index + 1]
            let clearance = inner.orbitalClearance(to: outer, around: planet.mass)
            guard policy.acceptsRadialClearance(
                clearance,
                additiveSlack: Self.moonOrbitalSlackMeters
            ) else {
                throw .unstableMoonPair(
                    parent: planet.id,
                    inner: inner.id,
                    outer: outer.id
                )
            }
        }
    }

    private func validateMassLedgers() throws(StarSystemGenerationError) {
        let seededEmbryoCount = formationLedger.seededEmbryoCount
        let dynamicalLosses = formationLedger.dynamicalLosses
        let residualComposition = formationLedger.residualBodyComposition
        try validateLedgerDestinationsAndCounts(
            seededEmbryoCount: seededEmbryoCount,
            dynamicalLosses: dynamicalLosses,
            residualComposition: residualComposition
        )
        try validateSurvivorAndAncestryClosure(
            seededEmbryoCount: seededEmbryoCount,
            dynamicalLosses: dynamicalLosses
        )
        try validateSolidMassClosure(
            dynamicalLosses: dynamicalLosses,
            residualComposition: residualComposition
        )
        try validateHydrogenHeliumMassClosure(
            dynamicalLosses: dynamicalLosses,
            residualComposition: residualComposition
        )
    }

    private func validateLedgerDestinationsAndCounts(
        seededEmbryoCount: Int,
        dynamicalLosses: StarSystemDynamicalLossLedger,
        residualComposition: CelestialMassComposition
    ) throws(StarSystemGenerationError) {
        guard (1...policy.maximumEmbryoCount).contains(seededEmbryoCount),
              (0...seededEmbryoCount).contains(formationLedger.formationMergerCount),
              (0...seededEmbryoCount).contains(formationLedger.postDiskCollisionMergerCount),
              (0...policy.maximumPostDiskEncounterCount).contains(
                  dynamicalLosses.scatteringCount
              ),
              (0...seededEmbryoCount).contains(dynamicalLosses.ejectedBodyCount),
              (0...seededEmbryoCount).contains(dynamicalLosses.ejectedProgenitorCount),
              dynamicalLosses.ejectedBodyCount <= dynamicalLosses.ejectedProgenitorCount,
              (0...seededEmbryoCount).contains(dynamicalLosses.starAccretedBodyCount),
              (0...seededEmbryoCount).contains(dynamicalLosses.starAccretedProgenitorCount),
              dynamicalLosses.starAccretedBodyCount <= dynamicalLosses.starAccretedProgenitorCount,
              isValidComposition(dynamicalLosses.ejectedComposition),
              isValidComposition(dynamicalLosses.starAccretedComposition),
              isValidComposition(dynamicalLosses.collisionDebrisComposition),
              lossCountsMatchComposition(dynamicalLosses),
              (0...seededEmbryoCount).contains(formationLedger.residualBodyCount),
              (0...seededEmbryoCount).contains(formationLedger.residualProgenitorCount),
              formationLedger.residualBodyCount <= formationLedger.residualProgenitorCount,
              isValidComposition(residualComposition),
              residualCountsMatchComposition(),
              residualComposition.solidMass.earthMasses
                <= policy.minimumResolvedPlanetSolidMassEarth
                    * Double(formationLedger.residualBodyCount)
                    * (1 + 1e-9),
              isNonnegativeFinite(formationLedger.initialSolidMass),
              isNonnegativeFinite(formationLedger.retainedSolidMass),
              isNonnegativeFinite(formationLedger.unaccretedSolidMass),
              isValidComposition(formationLedger.unaccretedSolidComposition),
              formationLedger.unaccretedSolidComposition.hydrogenHelium == .zero,
              isNonnegativeFinite(formationLedger.initialGasMass),
              isNonnegativeFinite(formationLedger.retainedHydrogenHeliumMass),
              isNonnegativeFinite(formationLedger.escapedHydrogenHeliumMass),
              isNonnegativeFinite(formationLedger.dispersedGasMass) else {
            throw .invalidFormationLedger
        }
    }

    private func validateSurvivorAndAncestryClosure(
        seededEmbryoCount: Int,
        dynamicalLosses: StarSystemDynamicalLossLedger
    ) throws(StarSystemGenerationError) {
        let retainedProgenitorCount = planets.reduce(0) { partial, planet in
            partial + planet.progenitorCount
        }
        let totalMergerCount = formationLedger.formationMergerCount
            + formationLedger.postDiskCollisionMergerCount
        let removedBodyCount = dynamicalLosses.ejectedBodyCount
            + dynamicalLosses.starAccretedBodyCount
        guard retainedProgenitorCount
                + formationLedger.residualProgenitorCount
                + dynamicalLosses.ejectedProgenitorCount
                + dynamicalLosses.starAccretedProgenitorCount == seededEmbryoCount,
              totalMergerCount + removedBodyCount < seededEmbryoCount,
              planets.count + formationLedger.residualBodyCount
                == seededEmbryoCount - totalMergerCount - removedBodyCount else {
            throw .invalidFormationLedger
        }
    }

    private func validateSolidMassClosure(
        dynamicalLosses: StarSystemDynamicalLossLedger,
        residualComposition: CelestialMassComposition
    ) throws(StarSystemGenerationError) {
        let actualSolid = allCompositions.reduce(0) { $0 + $1.solidMass.earthMasses }
        let dynamicalSolidMass = dynamicalLosses.ejectedComposition.solidMass.earthMasses
            + dynamicalLosses.starAccretedComposition.solidMass.earthMasses
            + dynamicalLosses.collisionDebrisComposition.solidMass.earthMasses
        guard actualSolid.isFinite,
              dynamicalSolidMass.isFinite,
              approximatelyEqual(actualSolid, formationLedger.retainedSolidMass.earthMasses),
              approximatelyEqual(
                  formationLedger.unaccretedSolidMass.earthMasses,
                  formationLedger.unaccretedSolidComposition.solidMass.earthMasses
              ),
              approximatelyEqual(
                formationLedger.initialSolidMass.earthMasses,
                formationLedger.retainedSolidMass.earthMasses
                    + formationLedger.unaccretedSolidMass.earthMasses
                    + residualComposition.solidMass.earthMasses
                    + dynamicalSolidMass
              ),
              approximatelyEqual(
                formationLedger.initialSolidMass.earthMasses,
                protoplanetaryDisk.initialSolidMass.earthMasses
              ),
              solidComponentsClose() else {
            throw .massConservationFailure(.solids)
        }
    }

    private func validateHydrogenHeliumMassClosure(
        dynamicalLosses: StarSystemDynamicalLossLedger,
        residualComposition: CelestialMassComposition
    ) throws(StarSystemGenerationError) {
        let actualGas = allCompositions.reduce(0) { $0 + $1.hydrogenHelium.earthMasses }
        let dynamicalHydrogenHeliumMass = dynamicalLosses.ejectedComposition
            .hydrogenHelium.earthMasses
            + dynamicalLosses.starAccretedComposition.hydrogenHelium.earthMasses
            + dynamicalLosses.collisionDebrisComposition.hydrogenHelium.earthMasses
        guard actualGas.isFinite,
              dynamicalHydrogenHeliumMass.isFinite,
              approximatelyEqual(actualGas, formationLedger.retainedHydrogenHeliumMass.earthMasses),
              approximatelyEqual(
                formationLedger.initialGasMass.earthMasses,
                formationLedger.retainedHydrogenHeliumMass.earthMasses
                    + formationLedger.escapedHydrogenHeliumMass.earthMasses
                    + formationLedger.dispersedGasMass.earthMasses
                    + residualComposition.hydrogenHelium.earthMasses
                    + dynamicalHydrogenHeliumMass
              ),
              approximatelyEqual(
                formationLedger.initialGasMass.earthMasses,
                protoplanetaryDisk.initialGasMass.earthMasses
              ) else {
            throw .massConservationFailure(.hydrogenHelium)
        }
    }

    private func lossCountsMatchComposition(
        _ losses: StarSystemDynamicalLossLedger
    ) -> Bool {
        return bodyAggregateMatches(
            bodyCount: losses.ejectedBodyCount,
            progenitorCount: losses.ejectedProgenitorCount,
            composition: losses.ejectedComposition
        )
            && bodyAggregateMatches(
                bodyCount: losses.starAccretedBodyCount,
                progenitorCount: losses.starAccretedProgenitorCount,
                composition: losses.starAccretedComposition
            )
            && collisionDebrisMatches()
    }

    private func residualCountsMatchComposition() -> Bool {
        bodyAggregateMatches(
            bodyCount: formationLedger.residualBodyCount,
            progenitorCount: formationLedger.residualProgenitorCount,
            composition: formationLedger.residualBodyComposition
        )
    }

    private func bodyAggregateMatches(
        bodyCount: Int,
        progenitorCount: Int,
        composition: CelestialMassComposition
    ) -> Bool {
        if bodyCount == 0 {
            return progenitorCount == 0 && composition == .zero
        }
        return progenitorCount >= bodyCount
            && composition.solidMass.earthMasses > 0
    }

    private func collisionDebrisMatches() -> Bool {
        if formationLedger.postDiskCollisionMergerCount == 0 {
            return formationLedger.dynamicalLosses.collisionDebrisComposition == .zero
        }
        return formationLedger.dynamicalLosses.collisionDebrisComposition
            .solidMass.earthMasses > 0
    }

    private func isValidPlanet(_ planet: GeneratedPlanet) -> Bool {
        let availableDiskMassEarth = protoplanetaryDisk.initialSolidMass.earthMasses
            + protoplanetaryDisk.initialGasMass.earthMasses
        return isValidComposition(planet.composition)
            && planet.composition.solidMass.kilograms > 0
            && planet.mass.kilograms > 0
            && planet.mass.earthMasses <= availableDiskMassEarth * (1 + 1e-9)
            && planet.radius.meters.isFinite
            && planet.radius.meters > 0
            && planet.orbit.semiMajorAxis.meters > star.radius.meters
            && planet.orbit.semiMajorAxis >= protoplanetaryDisk.innerEdge
            && planet.orbit.semiMajorAxis.meters
                * (1 - planet.orbit.eccentricity.rawValue) > star.radius.meters
            && planet.orbit.semiMajorAxis <= protoplanetaryDisk.outerEdge
            && isValidOrbit(planet.orbit)
            && isValidEnvironment(planet.environment)
            && (1...policy.maximumEmbryoCount).contains(planet.progenitorCount)
    }

    private func isValidMoon(_ moon: GeneratedMoon) -> Bool {
        isValidComposition(moon.composition)
            && moon.composition.solidMass.kilograms > 0
            && moon.mass.kilograms > 0
            && moon.radius.meters.isFinite
            && moon.radius.meters > 0
            && moon.minimumStableOrbit.meters.isFinite
            && moon.minimumStableOrbit.meters > 0
            && moon.maximumStableOrbit.meters.isFinite
            && moon.maximumStableOrbit > moon.minimumStableOrbit
            && moon.orbit.semiMajorAxis.meters + Self.moonOrbitalSlackMeters
                >= moon.minimumStableOrbit.meters
            && moon.orbit.semiMajorAxis.meters - Self.moonOrbitalSlackMeters
                <= moon.maximumStableOrbit.meters
            && isValidOrbit(moon.orbit)
            && isValidEnvironment(moon.environment)
    }

    private func isValidComposition(_ composition: CelestialMassComposition) -> Bool {
        let components = [
            composition.iron.kilograms,
            composition.silicate.kilograms,
            composition.water.kilograms,
            composition.otherVolatiles.kilograms,
            composition.hydrogenHelium.kilograms
        ]
        guard components.allSatisfy({ $0.isFinite && $0 >= 0 }) else {
            return false
        }
        let totalKilograms = components.reduce(0, +)
        let availableDiskKilograms = protoplanetaryDisk.initialSolidMass.kilograms
            + protoplanetaryDisk.initialGasMass.kilograms
        return totalKilograms.isFinite
            && availableDiskKilograms.isFinite
            && totalKilograms <= availableDiskKilograms
    }

    private func isValidEnvironment(_ environment: PlanetaryEnvironment) -> Bool {
        environment.incidentFluxEarth.isFinite
            && environment.incidentFluxEarth >= 0
            && environment.equilibriumTemperature.kelvin.isFinite
            && environment.equilibriumTemperature.kelvin >= 0
            && environment.visibleBoundaryTemperature.kelvin.isFinite
            && environment.visibleBoundaryTemperature.kelvin >= 0
            && environment.atmosphereMass.kilograms.isFinite
            && environment.atmosphereMass.kilograms >= 0
            && isValidSurfacePressure(environment.surfacePressure)
            && acceptsUnitFraction(environment.bondAlbedo)
            && acceptsUnitFraction(environment.liquidWaterCoverage)
            && acceptsUnitFraction(environment.waterIceCoverage)
    }

    private func isValidOrbit(_ orbit: KeplerianOrbit) -> Bool {
        orbit.semiMajorAxis.meters.isFinite
            && orbit.semiMajorAxis.meters > 0
            && OrbitalEccentricity.accepts(orbit.eccentricity.rawValue)
            && orbit.inclinationDegrees.isFinite
            && orbit.inclinationDegrees >= 0
            && orbit.inclinationDegrees <= 180
    }

    private func acceptsUnitFraction(_ value: Double) -> Bool {
        value.isFinite && value >= 0 && value <= 1
    }

    private func isValidSurfacePressure(_ pressure: SurfacePressure?) -> Bool {
        guard let pressure else {
            return true
        }
        return pressure.pascals.isFinite && pressure.pascals >= 0
    }

    private func isPlanetIdentity(_ identity: GeneratedBodyID) -> Bool {
        guard formationLedger.seededEmbryoCount > 0 else {
            return false
        }
        return identity.isPlanet
            && identity.rawValue <= UInt64(formationLedger.seededEmbryoCount)
    }

    private func isMoonIdentity(
        _ identity: GeneratedBodyID,
        parent: GeneratedBodyID
    ) -> Bool {
        guard identity.parentPlanetID == parent,
              let formationIndex = identity.moonFormationIndex else {
            return false
        }
        return formationIndex < policy.maximumMoonCountPerPlanet
    }

    private func isNonnegativeFinite(_ mass: AstronomicalMass) -> Bool {
        mass.kilograms.isFinite && mass.kilograms >= 0
    }

    private func solidMassKilograms(in composition: CelestialMassComposition) -> Double {
        composition.iron.kilograms
            + composition.silicate.kilograms
            + composition.water.kilograms
            + composition.otherVolatiles.kilograms
    }

    private func solidComponentsClose() -> Bool {
        let initial = protoplanetaryDisk.initialSolidComposition
        let unaccreted = formationLedger.unaccretedSolidComposition
        let losses = formationLedger.dynamicalLosses
        let residual = formationLedger.residualBodyComposition
        let retainedIron = allCompositions.reduce(0) { $0 + $1.iron.earthMasses }
        let retainedSilicate = allCompositions.reduce(0) { $0 + $1.silicate.earthMasses }
        let retainedWater = allCompositions.reduce(0) { $0 + $1.water.earthMasses }
        let retainedOtherVolatiles = allCompositions.reduce(0) {
            $0 + $1.otherVolatiles.earthMasses
        }
        let dynamicalIron = losses.ejectedComposition.iron.earthMasses
            + losses.starAccretedComposition.iron.earthMasses
            + losses.collisionDebrisComposition.iron.earthMasses
        let dynamicalSilicate = losses.ejectedComposition.silicate.earthMasses
            + losses.starAccretedComposition.silicate.earthMasses
            + losses.collisionDebrisComposition.silicate.earthMasses
        let dynamicalWater = losses.ejectedComposition.water.earthMasses
            + losses.starAccretedComposition.water.earthMasses
            + losses.collisionDebrisComposition.water.earthMasses
        let dynamicalOtherVolatiles = losses.ejectedComposition.otherVolatiles.earthMasses
            + losses.starAccretedComposition.otherVolatiles.earthMasses
            + losses.collisionDebrisComposition.otherVolatiles.earthMasses
        guard retainedIron.isFinite,
              retainedSilicate.isFinite,
              retainedWater.isFinite,
              retainedOtherVolatiles.isFinite,
              dynamicalIron.isFinite,
              dynamicalSilicate.isFinite,
              dynamicalWater.isFinite,
              dynamicalOtherVolatiles.isFinite else {
            return false
        }
        return approximatelyEqual(
            initial.iron.earthMasses,
            retainedIron
                + unaccreted.iron.earthMasses
                + residual.iron.earthMasses
                + dynamicalIron
        )
            && approximatelyEqual(
                initial.silicate.earthMasses,
                retainedSilicate
                    + unaccreted.silicate.earthMasses
                    + residual.silicate.earthMasses
                    + dynamicalSilicate
            )
            && approximatelyEqual(
                initial.water.earthMasses,
                retainedWater
                    + unaccreted.water.earthMasses
                    + residual.water.earthMasses
                    + dynamicalWater
            )
            && approximatelyEqual(
                initial.otherVolatiles.earthMasses,
                retainedOtherVolatiles
                    + unaccreted.otherVolatiles.earthMasses
                    + residual.otherVolatiles.earthMasses
                    + dynamicalOtherVolatiles
            )
    }

    private func starsApproximatelyEqual(_ first: GeneratedStar, _ second: GeneratedStar) -> Bool {
        approximatelyEqual(first.mass.kilograms, second.mass.kilograms)
            && approximatelyEqual(first.metallicityDex, second.metallicityDex)
            && approximatelyEqual(first.age.seconds, second.age.seconds)
            && approximatelyEqual(first.luminosity.watts, second.luminosity.watts)
            && approximatelyEqual(first.radius.meters, second.radius.meters)
            && approximatelyEqual(
                first.effectiveTemperature.kelvin,
                second.effectiveTemperature.kelvin
            )
            && first.activityRegime == second.activityRegime
            && approximatelyEqual(
                first.xuvLuminosityFraction,
                second.xuvLuminosityFraction
            )
    }

    private func disksApproximatelyEqual(
        _ first: GeneratedProtoplanetaryDisk,
        _ second: GeneratedProtoplanetaryDisk
    ) -> Bool {
        approximatelyEqual(first.initialGasMass.kilograms, second.initialGasMass.kilograms)
            && approximatelyEqual(first.initialSolidMass.kilograms, second.initialSolidMass.kilograms)
            && compositionsApproximatelyEqual(
                first.initialSolidComposition,
                second.initialSolidComposition
            )
            && approximatelyEqual(first.lifetime.seconds, second.lifetime.seconds)
            && approximatelyEqual(
                first.characteristicRadius.meters,
                second.characteristicRadius.meters
            )
            && approximatelyEqual(first.surfaceDensityExponent, second.surfaceDensityExponent)
            && approximatelyEqual(first.innerEdge.meters, second.innerEdge.meters)
            && approximatelyEqual(first.outerEdge.meters, second.outerEdge.meters)
            && approximatelyEqual(first.waterSnowLine.meters, second.waterSnowLine.meters)
            && first.annulusCount == second.annulusCount
    }

    private func compositionsApproximatelyEqual(
        _ first: CelestialMassComposition,
        _ second: CelestialMassComposition
    ) -> Bool {
        approximatelyEqual(first.iron.kilograms, second.iron.kilograms)
            && approximatelyEqual(first.silicate.kilograms, second.silicate.kilograms)
            && approximatelyEqual(first.water.kilograms, second.water.kilograms)
            && approximatelyEqual(first.otherVolatiles.kilograms, second.otherVolatiles.kilograms)
            && approximatelyEqual(first.hydrogenHelium.kilograms, second.hydrogenHelium.kilograms)
    }

    private func environmentsApproximatelyEqual(
        _ first: PlanetaryEnvironment,
        _ second: PlanetaryEnvironment
    ) -> Bool {
        approximatelyEqual(first.incidentFluxEarth, second.incidentFluxEarth)
            && approximatelyEqual(
                first.equilibriumTemperature.kelvin,
                second.equilibriumTemperature.kelvin
            )
            && approximatelyEqual(
                first.visibleBoundaryTemperature.kelvin,
                second.visibleBoundaryTemperature.kelvin
            )
            && approximatelyEqual(first.atmosphereMass.kilograms, second.atmosphereMass.kilograms)
            && pressuresApproximatelyEqual(first.surfacePressure, second.surfacePressure)
            && approximatelyEqual(first.bondAlbedo, second.bondAlbedo)
            && approximatelyEqual(first.liquidWaterCoverage, second.liquidWaterCoverage)
            && approximatelyEqual(first.waterIceCoverage, second.waterIceCoverage)
    }

    private func pressuresApproximatelyEqual(
        _ first: SurfacePressure?,
        _ second: SurfacePressure?
    ) -> Bool {
        switch (first, second) {
        case (.none, .none):
            true
        case let (.some(first), .some(second)):
            approximatelyEqual(first.pascals, second.pascals)
        default:
            false
        }
    }

    private func approximatelyEqual(_ first: Double, _ second: Double) -> Bool {
        guard first.isFinite, second.isFinite else {
            return false
        }
        let scale = max(abs(first), abs(second), 1)
        return abs(first - second) <= scale * 1e-9
    }
}
