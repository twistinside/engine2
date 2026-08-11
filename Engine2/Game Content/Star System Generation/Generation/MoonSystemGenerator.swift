import Foundation

/// Forms a bounded set of significant regular or impact moons from parent material.
///
/// V1 generates only satellites massive enough to matter to the resolved system
/// description. Captured irregular moons, rings, resonant evolution, and debris
/// swarms remain deferred.
nonisolated struct MoonSystemGenerator: Sendable {
    let policy: StarSystemGenerationPolicy
    let environmentResolver: PlanetaryEnvironmentResolver

    func extractMoonSeeds(
        from parent: inout FormationEmbryo,
        around star: GeneratedStar,
        seed: StarSystemSeed
    ) -> [FormationMoonSeed] {
        guard policy.maximumMoonCountPerPlanet > 0 else {
            return []
        }
        var random = StarSystemRandomStream(
            seed: seed,
            modelVersion: policy.modelVersion,
            domain: .moons,
            discriminator: parent.id.rawValue
        )
        let totalMass = parent.composition.totalMass.earthMasses
        let solidMass = parent.composition.solidMass.earthMasses
        guard solidMass > 1e-6, hasStableSatelliteRegion(parent, around: star) else {
            return []
        }

        let moonSpecification = moonSpecification(
            parent: parent,
            totalMassEarth: totalMass,
            solidMassEarth: solidMass,
            random: &random
        )
        guard let moonSpecification else {
            return []
        }
        let weights = normalizedMoonWeights(count: moonSpecification.count, random: &random)
        let totalFraction = min(moonSpecification.totalMassEarth / solidMass, 0.05)
        let parentSolid = solidOnly(parent.composition)
        let moonSeeds = weights.indices.map { index in
            FormationMoonSeed(
                id: .moon(parent: parent.id, formationIndex: index),
                origin: moonSpecification.origin,
                composition: parentSolid.scaled(by: totalFraction * weights[index]),
                normalizedOrbitIndex: Double(index + 1) / Double(weights.count + 1)
            )
        }
        parent.composition = retainedParentComposition(
            from: parent.composition,
            retainedSolidFraction: 1 - totalFraction
        )
        return moonSeeds
    }

    func resolveMoons(
        _ seeds: [FormationMoonSeed],
        around parent: EvolvedPlanetaryBody,
        on parentOrbit: KeplerianOrbit,
        star: GeneratedStar,
        rootSeed: StarSystemSeed
    ) -> [GeneratedMoon] {
        var retainedSeeds = seeds
        while true {
            let resolvedSeeds = retainedSeeds.enumerated().map { seedIndex, moonSeed in
                (
                    seedIndex: seedIndex,
                    seed: moonSeed,
                    moon: resolveMoon(
                        moonSeed,
                        around: parent,
                        on: parentOrbit,
                        star: star,
                        rootSeed: rootSeed
                    )
                )
            }
            .sorted { $0.moon.orbit.semiMajorAxis < $1.moon.orbit.semiMajorAxis }
            let moons = resolvedSeeds.map(\.moon)
            guard let unstableIndex = firstUnstablePairIndex(
                in: moons,
                parentMass: parent.composition.totalMass
            ) else {
                return moons
            }
            let innerSeed = resolvedSeeds[unstableIndex]
            let outerSeed = resolvedSeeds[unstableIndex + 1]
            let merged = mergedMoonSeed(innerSeed.seed, outerSeed.seed)
            retainedSeeds.remove(at: max(innerSeed.seedIndex, outerSeed.seedIndex))
            retainedSeeds.remove(at: min(innerSeed.seedIndex, outerSeed.seedIndex))
            retainedSeeds.append(merged)
        }
    }

    private func resolveMoon(
        _ moonSeed: FormationMoonSeed,
        around parent: EvolvedPlanetaryBody,
        on parentOrbit: KeplerianOrbit,
        star: GeneratedStar,
        rootSeed: StarSystemSeed
    ) -> GeneratedMoon {
        let evolvedMoon = environmentResolver.resolve(
            composition: moonSeed.composition,
            orbit: parentOrbit,
            around: star
        )
        var random = StarSystemRandomStream(
            seed: rootSeed,
            modelVersion: policy.modelVersion,
            domain: .moons,
            discriminator: moonSeed.id.rawValue
        )
        let eccentricity = min(random.rayleigh(scale: 0.005), 0.04)
        let stableBounds = satelliteStableBounds(
            parent: parent,
            moon: evolvedMoon,
            parentOrbit: parentOrbit,
            moonEccentricity: eccentricity,
            star: star
        )
        let orbitDistance = logarithmicInterpolation(
            from: stableBounds.minimum.meters,
            to: stableBounds.maximum.meters,
            fraction: moonSeed.normalizedOrbitIndex
        )
        return GeneratedMoon(
            id: moonSeed.id,
            origin: moonSeed.origin,
            composition: evolvedMoon.composition,
            radius: evolvedMoon.radius,
            orbit: KeplerianOrbit(
                semiMajorAxis: AstronomicalDistance(meters: orbitDistance),
                eccentricity: OrbitalEccentricity(rawValue: eccentricity),
                inclinationDegrees: min(abs(random.normal(standardDeviation: 1)), 10)
            ),
            minimumStableOrbit: stableBounds.minimum,
            maximumStableOrbit: stableBounds.maximum,
            environment: evolvedMoon.environment,
            physicalState: evolvedMoon.physicalState
        )
    }

    private func firstUnstablePairIndex(
        in moons: [GeneratedMoon],
        parentMass: AstronomicalMass
    ) -> Int? {
        guard moons.count > 1 else {
            return nil
        }
        for index in 0..<(moons.count - 1) {
            let inner = moons[index]
            let outer = moons[index + 1]
            let clearance = inner.orbitalClearance(
                to: outer,
                around: parentMass
            )
            if !policy.acceptsRadialClearance(clearance) {
                return index
            }
        }
        return nil
    }

    private func mergedMoonSeed(
        _ first: FormationMoonSeed,
        _ second: FormationMoonSeed
    ) -> FormationMoonSeed {
        let firstMass = first.composition.totalMass.earthMasses
        let secondMass = second.composition.totalMass.earthMasses
        let totalMass = firstMass + secondMass
        let normalizedOrbitIndex = (
            first.normalizedOrbitIndex * firstMass
                + second.normalizedOrbitIndex * secondMass
        ) / totalMass
        return FormationMoonSeed(
            id: min(first.id, second.id),
            origin: first.origin,
            composition: first.composition.adding(second.composition),
            normalizedOrbitIndex: normalizedOrbitIndex
        )
    }

    private func moonSpecification(
        parent: FormationEmbryo,
        totalMassEarth: Double,
        solidMassEarth: Double,
        random: inout StarSystemRandomStream
    ) -> (origin: MoonFormationOrigin, count: Int, totalMassEarth: Double)? {
        let hasDeepPrimordialEnvelope = parent.composition.hydrogenHeliumMassFraction >= 0.10
            && totalMassEarth >= 10
        if hasDeepPrimordialEnvelope {
            let count = min(policy.maximumMoonCountPerPlanet, random.integer(in: 1...4))
            let satelliteBudget = min(solidMassEarth * 0.02, totalMassEarth * 2e-4)
            guard count > 0, satelliteBudget > 1e-7 else {
                return nil
            }
            return (.circumplanetaryDisk, count, satelliteBudget)
        }
        guard parent.progenitorCount > 1,
              totalMassEarth >= 0.1,
              random.uniformUnit() < 0.40 else {
            return nil
        }
        return (.giantImpact, 1, solidMassEarth * random.uniform(in: 0.002...0.015))
    }

    private func normalizedMoonWeights(
        count: Int,
        random: inout StarSystemRandomStream
    ) -> [Double] {
        let weights = (0..<count).map { _ in random.uniform(in: 0.5...1.5) }
        let total = weights.reduce(0, +)
        return weights.map { $0 / total }
    }

    private func hasStableSatelliteRegion(
        _ parent: FormationEmbryo,
        around star: GeneratedStar
    ) -> Bool {
        let parentRadiusEarth = conservativeParentRadiusEarth(parent.composition)
        let parentRadiusAU = AstronomicalDistance(earthRadii: parentRadiusEarth).astronomicalUnits
        let hillRadiusAU = parent.semiMajorAxisAU
            * pow(parent.composition.totalMass.earthMasses / (3 * star.mass.earthMasses), 1.0 / 3.0)
        let maximumMoonEccentricity = 0.04
        let criticalFactor = progradeCriticalHillFactor(
            planetEccentricity: parent.eccentricity,
            moonEccentricity: maximumMoonEccentricity
        )
        let minimumAxisAU = 6 * parentRadiusAU / (1 - maximumMoonEccentricity)
        return criticalFactor * hillRadiusAU > minimumAxisAU
    }

    func satelliteStableBounds(
        parent: EvolvedPlanetaryBody,
        moon: EvolvedPlanetaryBody,
        parentOrbit: KeplerianOrbit,
        moonEccentricity: Double,
        star: GeneratedStar
    ) -> (minimum: AstronomicalDistance, maximum: AstronomicalDistance) {
        let parentMassEarth = parent.composition.totalMass.earthMasses
        let moonMassEarth = moon.composition.totalMass.earthMasses
        let parentRadiusEarth = parent.radius.earthRadii
        let moonRadiusEarth = moon.radius.earthRadii
        let parentDensityEarth = parentMassEarth / max(pow(parentRadiusEarth, 3), 1e-12)
        let moonDensityEarth = moonMassEarth / max(pow(moonRadiusEarth, 3), 1e-12)
        let rocheRadii = 2.44 * pow(parentDensityEarth / max(moonDensityEarth, 1e-12), 1.0 / 3.0)
        let minimumRadialDistance = parent.radius.meters * max(6, 1.05 * rocheRadii)
        let minimumMeters = minimumRadialDistance / (1 - moonEccentricity)
        let hillRadiusMeters = parentOrbit.semiMajorAxis.meters
            * pow(parentMassEarth / (3 * star.mass.earthMasses), 1.0 / 3.0)
        let criticalFactor = progradeCriticalHillFactor(
            planetEccentricity: parentOrbit.eccentricity.rawValue,
            moonEccentricity: moonEccentricity
        )
        let maximumMeters = criticalFactor * hillRadiusMeters
        return (
            AstronomicalDistance(meters: minimumMeters),
            AstronomicalDistance(meters: maximumMeters)
        )
    }

    private func progradeCriticalHillFactor(
        planetEccentricity: Double,
        moonEccentricity: Double
    ) -> Double {
        max(
            0.05,
            0.4895 * (1 - 1.0305 * planetEccentricity - 0.2738 * moonEccentricity)
        )
    }

    private func retainedParentComposition(
        from composition: CelestialMassComposition,
        retainedSolidFraction: Double
    ) -> CelestialMassComposition {
        let retainedSolids = solidOnly(composition).scaled(by: retainedSolidFraction)
        return retainedSolids.replacingHydrogenHelium(with: composition.hydrogenHelium)
    }

    private func solidOnly(_ composition: CelestialMassComposition) -> CelestialMassComposition {
        composition.replacingHydrogenHelium(with: .zero)
    }

    private func conservativeParentRadiusEarth(_ composition: CelestialMassComposition) -> Double {
        let solidMass = max(composition.solidMass.earthMasses, 1e-8)
        let solidRadius = max(0.03, pow(solidMass, 0.27) * (1 + 0.25 * composition.waterMassFraction))
        if composition.hydrogenHeliumMassFraction >= 0.5 {
            return max(solidRadius, 14)
        }
        if composition.hydrogenHeliumMassFraction > 1e-5 {
            return max(solidRadius, 10)
        }
        return solidRadius
    }

    private func logarithmicInterpolation(from lower: Double, to upper: Double, fraction: Double) -> Double {
        exp(log(lower) + (log(upper) - log(lower)) * fraction)
    }
}
