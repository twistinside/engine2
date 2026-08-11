import Foundation

/// Generates and numerically normalizes one conserved logarithmic annular disk.
nonisolated struct ProtoplanetaryDiskGenerator: Sendable {
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
        let diskMassRatio = clamped(
            random.logNormal10(median: policy.medianDiskMassRatio, scatterDex: policy.diskMassScatterDex),
            to: policy.minimumDiskMassRatio...policy.maximumDiskMassRatio
        )
        let lifetimeMegayears = clamped(
            random.logNormal10(
                median: policy.medianDiskLifetimeMegayears,
                scatterDex: policy.diskLifetimeScatterDex
            ),
            to: policy.minimumDiskLifetimeMegayears...policy.maximumDiskLifetimeMegayears
        )
        let characteristicRadiusAU = clamped(
            random.logNormal10(
                median: policy.medianCharacteristicRadiusAU * sqrt(star.mass.solarMasses),
                scatterDex: policy.characteristicRadiusScatterDex
            ),
            to: 10...100
        )
        let surfaceDensityExponent = clamped(
            random.normal(mean: 1, standardDeviation: 0.2),
            to: 0.5...1.5
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
            diskMassRatio: diskMassRatio,
            lifetimeMegayears: lifetimeMegayears,
            characteristicRadiusAU: characteristicRadiusAU,
            surfaceDensityExponent: surfaceDensityExponent,
            innerIronFraction: ironFraction,
            innerWaterFraction: innerWaterFraction,
            solidFraction: solidFraction
        )
    }

    private func makeLayout(
        from sample: SampledProtoplanetaryDisk,
        around star: GeneratedStar
    ) -> ProtoplanetaryDiskLayout {
        let gasMassEarth = star.mass.earthMasses * sample.diskMassRatio
        let solidMassEarth = gasMassEarth * sample.solidFraction
        let innerEdgeAU = max(
            0.03,
            1.15 * star.radius.astronomicalUnits
        )
        let outerEdgeAU = max(innerEdgeAU * 4, min(40, 3 * sample.characteristicRadiusAU))
        let formationLuminositySolar = max(
            star.luminosity.solarLuminosities,
            1.5 * pow(star.mass.solarMasses, 2)
        )
        let snowLineAU = 2.7 * sqrt(formationLuminositySolar)
        let radialEdges = logarithmicEdges(
            lower: innerEdgeAU,
            upper: outerEdgeAU,
            count: policy.annulusCount
        )
        let weights = annulusWeights(
            radialEdges: radialEdges,
            characteristicRadiusAU: sample.characteristicRadiusAU,
            exponent: sample.surfaceDensityExponent
        )
        return ProtoplanetaryDiskLayout(
            gasMassEarth: gasMassEarth,
            solidMassEarth: solidMassEarth,
            innerEdgeAU: innerEdgeAU,
            outerEdgeAU: outerEdgeAU,
            snowLineAU: snowLineAU,
            radialEdges: radialEdges,
            normalizedAnnulusWeights: normalized(weights)
        )
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

    private func logarithmicEdges(lower: Double, upper: Double, count: Int) -> [Double] {
        let logarithmicStep = log(upper / lower) / Double(count)
        return (0...count).map { index in
            lower * exp(Double(index) * logarithmicStep)
        }
    }

    private func annulusWeights(
        radialEdges: [Double],
        characteristicRadiusAU: Double,
        exponent: Double
    ) -> [Double] {
        (0..<(radialEdges.count - 1)).map { index in
            let inner = radialEdges[index]
            let outer = radialEdges[index + 1]
            let center = sqrt(inner * outer)
            let scaledRadius = center / characteristicRadiusAU
            let surfaceDensity = pow(scaledRadius, -exponent)
                * exp(-pow(scaledRadius, 2 - exponent))
            return 2 * Double.pi * center * (outer - inner) * surfaceDensity
        }
    }

    private func normalized(_ values: [Double]) -> [Double] {
        let total = values.reduce(0, +)
        precondition(total.isFinite && total > 0, "Disk annulus weights must have a positive finite sum.")
        return values.map { $0 / total }
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
