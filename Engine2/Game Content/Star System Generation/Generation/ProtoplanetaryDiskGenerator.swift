import Foundation

/// Generates one conserved logarithmic annular disk admitted by V1's stability bound.
///
/// V1 correlates characteristic radius with sampled gas-disk mass, rejects structures
/// below its annular Toomre-Q bound, and stores only the mass represented between
/// the resolved inner and outer edges.
nonisolated struct ProtoplanetaryDiskGenerator: Sendable {
    private static let diskMassRadiusExponent = 0.625

    let policy: StarSystemGenerationPolicy

    func generate(around star: GeneratedStar, seed: StarSystemSeed) -> FormationDisk {
        var random = StarSystemRandomStream(
            seed: seed,
            modelVersion: policy.modelVersion,
            domain: .disk
        )
        let sample = sampleDisk(around: star, random: &random)
        let layout = makeLayout(from: sample, around: star)
        let annuli = makeAnnuli(
            radialEdges: layout.radialEdges,
            normalizedWeights: layout.normalizedAnnulusWeights,
            totalGasMassEarth: layout.gasMassEarth,
            totalSolidMassEarth: layout.solidMassEarth,
            snowLineAU: layout.snowLineAU,
            innerIronFraction: sample.innerIronFraction,
            innerWaterFraction: sample.innerWaterFraction
        )
        let initialSolidComposition = annuli.reduce(CelestialMassComposition.zero) {
            $0.adding($1.solidComposition)
        }
        let summary = makeSummary(
            sample: sample,
            layout: layout,
            initialSolidComposition: initialSolidComposition
        )
        return FormationDisk(summary: summary, annuli: annuli, dispersedGasMassEarth: 0)
    }

    private func sampleDisk(
        around star: GeneratedStar,
        random: inout StarSystemRandomStream
    ) -> SampledProtoplanetaryDisk {
        let diskStructure = sampleSupportedDiskStructure(
            around: star,
            random: &random
        )
        let lifetimeMegayears = clamped(
            random.logNormal10(
                median: policy.medianDiskLifetimeMegayears,
                scatterDex: policy.diskLifetimeScatterDex
            ),
            to: policy.minimumDiskLifetimeMegayears...policy.maximumDiskLifetimeMegayears
        )
        let ironFraction = clamped(random.normal(mean: 0.32, standardDeviation: 0.05), to: 0.20...0.42)
        let innerWaterFraction = random.uniformUnit() < 0.45
            ? 0
            : pow(10, random.uniform(in: -4.5 ... -0.7))
        let solidFraction = clamped(
            policy.baseSolidFraction
                * pow(10, star.metallicityDex + random.normal(standardDeviation: 0.1)),
            to: 0.002...0.05
        )
        return SampledProtoplanetaryDisk(
            diskMassRatio: diskStructure.massRatio,
            lifetimeMegayears: lifetimeMegayears,
            characteristicRadiusAU: diskStructure.characteristicRadiusAU,
            surfaceDensityExponent: diskStructure.surfaceDensityExponent,
            innerIronFraction: ironFraction,
            innerWaterFraction: innerWaterFraction,
            solidFraction: solidFraction
        )
    }

    private func sampleSupportedDiskStructure(
        around star: GeneratedStar,
        random: inout StarSystemRandomStream
    ) -> (massRatio: Double, characteristicRadiusAU: Double, surfaceDensityExponent: Double) {
        var finalRadiusScatter = 1.0
        var finalSurfaceDensityExponent = 1.0
        for _ in 0..<16 {
            let massRatio = clamped(
                random.logNormal10(
                    median: policy.medianDiskMassRatio,
                    scatterDex: policy.diskMassScatterDex
                ),
                to: policy.minimumDiskMassRatio...policy.maximumDiskMassRatio
            )
            finalRadiusScatter = pow(
                10,
                policy.characteristicRadiusScatterDex * random.normal()
            )
            finalSurfaceDensityExponent = clamped(
                random.normal(mean: 1, standardDeviation: 0.2),
                to: 0.5...1.5
            )
            let characteristicRadiusAU = correlatedCharacteristicRadiusAU(
                forDiskMassRatio: massRatio,
                radiusScatter: finalRadiusScatter,
                around: star
            )
            let profile = diskProfile(
                characteristicRadiusAU: characteristicRadiusAU,
                surfaceDensityExponent: finalSurfaceDensityExponent,
                around: star
            )
            let stabilityLimitedMaximumRatio = profile.maximumStableDiskMassRatio(around: star)
            if massRatio <= stabilityLimitedMaximumRatio {
                return (massRatio, characteristicRadiusAU, finalSurfaceDensityExponent)
            }
        }

        let fallbackMassRatio = policy.minimumDiskMassRatio
        let fallbackRadiusAU = correlatedCharacteristicRadiusAU(
            forDiskMassRatio: fallbackMassRatio,
            radiusScatter: finalRadiusScatter,
            around: star
        )
        let profile = diskProfile(
            characteristicRadiusAU: fallbackRadiusAU,
            surfaceDensityExponent: finalSurfaceDensityExponent,
            around: star
        )
        let stabilityLimitedMaximumRatio = profile.maximumStableDiskMassRatio(around: star)
        precondition(
            fallbackMassRatio <= stabilityLimitedMaximumRatio,
            "The minimum supported disk prior must remain Toomre stable."
        )
        return (fallbackMassRatio, fallbackRadiusAU, finalSurfaceDensityExponent)
    }

    private func correlatedCharacteristicRadiusAU(
        forDiskMassRatio massRatio: Double,
        radiusScatter: Double,
        around star: GeneratedStar
    ) -> Double {
        let diskMassRelativeToMedianSolarDisk = massRatio
            * star.mass.solarMasses
            / policy.medianDiskMassRatio
        return clamped(
            policy.medianCharacteristicRadiusAU
                * pow(diskMassRelativeToMedianSolarDisk, Self.diskMassRadiusExponent)
                * radiusScatter,
            to: 10...100
        )
    }

    private func makeLayout(
        from sample: SampledProtoplanetaryDisk,
        around star: GeneratedStar
    ) -> ProtoplanetaryDiskLayout {
        let innerEdgeAU = diskInnerEdgeAU(around: star)
        let profile = ProtoplanetaryDiskProfile(
            characteristicRadiusAU: sample.characteristicRadiusAU,
            surfaceDensityExponent: sample.surfaceDensityExponent,
            innerEdgeAU: innerEdgeAU,
            annulusCount: policy.annulusCount
        )
        let gasMassEarth = star.mass.earthMasses
            * sample.diskMassRatio
            * profile.representedMassFraction
        let solidMassEarth = gasMassEarth * sample.solidFraction
        let formationLuminositySolar = max(
            star.luminosity.solarLuminosities,
            1.5 * pow(star.mass.solarMasses, 2)
        )
        let snowLineAU = 2.7 * sqrt(formationLuminositySolar)
        return ProtoplanetaryDiskLayout(
            gasMassEarth: gasMassEarth,
            solidMassEarth: solidMassEarth,
            innerEdgeAU: innerEdgeAU,
            outerEdgeAU: profile.outerEdgeAU,
            snowLineAU: snowLineAU,
            radialEdges: profile.radialEdges,
            normalizedAnnulusWeights: profile.normalizedAnnulusWeights
        )
    }

    private func diskProfile(
        characteristicRadiusAU: Double,
        surfaceDensityExponent: Double,
        around star: GeneratedStar
    ) -> ProtoplanetaryDiskProfile {
        return ProtoplanetaryDiskProfile(
            characteristicRadiusAU: characteristicRadiusAU,
            surfaceDensityExponent: surfaceDensityExponent,
            innerEdgeAU: diskInnerEdgeAU(around: star),
            annulusCount: policy.annulusCount
        )
    }

    private func diskInnerEdgeAU(around star: GeneratedStar) -> Double {
        max(0.03, 1.15 * star.radius.astronomicalUnits)
    }

    private func makeSummary(
        sample: SampledProtoplanetaryDisk,
        layout: ProtoplanetaryDiskLayout,
        initialSolidComposition: CelestialMassComposition
    ) -> GeneratedProtoplanetaryDisk {
        GeneratedProtoplanetaryDisk(
            initialGasMass: AstronomicalMass(earthMasses: layout.gasMassEarth),
            initialSolidMass: AstronomicalMass(earthMasses: layout.solidMassEarth),
            initialSolidComposition: initialSolidComposition,
            lifetime: AstronomicalDuration(megayears: sample.lifetimeMegayears),
            characteristicRadius: AstronomicalDistance(
                astronomicalUnits: sample.characteristicRadiusAU
            ),
            surfaceDensityExponent: sample.surfaceDensityExponent,
            innerEdge: AstronomicalDistance(astronomicalUnits: layout.innerEdgeAU),
            outerEdge: AstronomicalDistance(astronomicalUnits: layout.outerEdgeAU),
            waterSnowLine: AstronomicalDistance(astronomicalUnits: layout.snowLineAU),
            annulusCount: policy.annulusCount
        )
    }

    private func makeAnnuli(
        radialEdges: [Double],
        normalizedWeights: [Double],
        totalGasMassEarth: Double,
        totalSolidMassEarth: Double,
        snowLineAU: Double,
        innerIronFraction: Double,
        innerWaterFraction: Double
    ) -> [FormationAnnulus] {
        normalizedWeights.indices.map { index in
            let inner = radialEdges[index]
            let outer = radialEdges[index + 1]
            let center = sqrt(inner * outer)
            let weight = normalizedWeights[index]
            let solidMass = totalSolidMassEarth * weight
            let composition = solidComposition(
                massEarth: solidMass,
                radiusAU: center,
                snowLineAU: snowLineAU,
                innerIronFraction: innerIronFraction,
                innerWaterFraction: innerWaterFraction
            )
            return FormationAnnulus(
                innerRadiusAU: inner,
                outerRadiusAU: outer,
                initialGasMassEarth: totalGasMassEarth * weight,
                remainingGasMassEarth: totalGasMassEarth * weight,
                solidComposition: composition
            )
        }
    }

    private func solidComposition(
        massEarth: Double,
        radiusAU: Double,
        snowLineAU: Double,
        innerIronFraction: Double,
        innerWaterFraction: Double
    ) -> CelestialMassComposition {
        let transition = clamped(
            (radiusAU / snowLineAU - 0.8) / 0.4,
            to: 0...1
        )
        let outerIronFraction = 0.10
        let outerSilicateFraction = 0.25
        let waterFraction = innerWaterFraction * (1 - transition) + 0.55 * transition
        let otherVolatileFraction = 0.10 * transition
        let ironFraction = innerIronFraction * (1 - transition) + outerIronFraction * transition
        let silicateFraction = (1 - innerIronFraction) * (1 - transition) + outerSilicateFraction * transition
        let fractionTotal = ironFraction + silicateFraction + waterFraction + otherVolatileFraction
        return CelestialMassComposition(
            iron: AstronomicalMass(earthMasses: massEarth * ironFraction / fractionTotal),
            silicate: AstronomicalMass(earthMasses: massEarth * silicateFraction / fractionTotal),
            water: AstronomicalMass(earthMasses: massEarth * waterFraction / fractionTotal),
            otherVolatiles: AstronomicalMass(earthMasses: massEarth * otherVolatileFraction / fractionTotal),
            hydrogenHelium: .zero
        )
    }

    private func clamped(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
