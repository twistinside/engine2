import Foundation

/// Evolves one primordial hydrogen-helium envelope through bounded post-disk loss phases.
///
/// Boil-off and core-powered loss run before logarithmic energy-limited XUV epochs.
/// Every phase subtracts an absolute mass budget, so complete stripping is representable.
nonisolated struct PrimordialAtmosphereEvolver: Sendable {
    private static let gravitationalConstant = 6.67430e-11
    private static let terrestrialBolometricFluxWattsPerSquareMeter = 1_361.0
    private static let hydrogenHeliumMeanMolecularMassKilograms = 2.3 * 1.672_621_925_95e-27
    private static let boltzmannConstant = 1.380_649e-23

    let policy: StarSystemGenerationPolicy
    let radiusResolver: PlanetaryRadiusResolver

    func evolve(
        _ initialComposition: CelestialMassComposition,
        incidentFluxEarth: Double,
        around star: GeneratedStar
    ) -> CelestialMassComposition {
        var retainedGas = retainedGasAfterPostDiskLoss(
            initialComposition,
            incidentFluxEarth: incidentFluxEarth
        )
        guard retainedGas > 0 else {
            return initialComposition.replacingHydrogenHelium(with: .zero)
        }
        let finalAgeGigayears = max(star.age.gigayears, 0.02)
        let logarithmicSpan = log(finalAgeGigayears / 0.01)

        for step in 0..<policy.evolutionStepCount {
            let lowerFraction = Double(step) / Double(policy.evolutionStepCount)
            let upperFraction = Double(step + 1) / Double(policy.evolutionStepCount)
            let lowerAge = 0.01 * exp(logarithmicSpan * lowerFraction)
            let upperAge = 0.01 * exp(logarithmicSpan * upperFraction)
            let middleAge = sqrt(lowerAge * upperAge)
            let currentComposition = initialComposition.replacingHydrogenHelium(
                with: AstronomicalMass(earthMasses: retainedGas)
            )
            let radiusEarth = radiusResolver.resolveVisibleRadiusEarth(
                composition: currentComposition,
                incidentFluxEarth: incidentFluxEarth,
                ageGigayears: middleAge
            )
            let historicXUVFraction = historicXUVLuminosityFraction(
                at: middleAge,
                finalAgeGigayears: finalAgeGigayears,
                around: star
            )
            let lossCapacity = energyLimitedLossEarthMasses(
                massEarth: currentComposition.totalMass.earthMasses,
                radiusEarth: radiusEarth,
                incidentFluxEarth: incidentFluxEarth,
                xuvLuminosityFraction: historicXUVFraction,
                durationGigayears: upperAge - lowerAge
            )
            retainedGas = max(0, retainedGas - lossCapacity)
            if retainedGas == 0 {
                break
            }
        }
        return initialComposition.replacingHydrogenHelium(
            with: AstronomicalMass(earthMasses: retainedGas)
        )
    }

    private func retainedGasAfterPostDiskLoss(
        _ initialComposition: CelestialMassComposition,
        incidentFluxEarth: Double
    ) -> Double {
        let equilibriumTemperatureKelvin = 278.5
            * pow(max(incidentFluxEarth * 0.7, 0), 0.25)
        let retainedAfterBoilOff = retainedGasAfterBoilOff(
            initialComposition,
            incidentFluxEarth: incidentFluxEarth,
            equilibriumTemperatureKelvin: equilibriumTemperatureKelvin
        )
        return retainedGasAfterCorePoweredLoss(
            retainedAfterBoilOff,
            solidMassEarth: initialComposition.solidMass.earthMasses,
            equilibriumTemperatureKelvin: equilibriumTemperatureKelvin
        )
    }

    private func retainedGasAfterBoilOff(
        _ initialComposition: CelestialMassComposition,
        incidentFluxEarth: Double,
        equilibriumTemperatureKelvin: Double
    ) -> Double {
        let initialGasEarth = initialComposition.hydrogenHelium.earthMasses
        let initialRadiusEarth = radiusResolver.resolveVisibleRadiusEarth(
            composition: initialComposition,
            incidentFluxEarth: incidentFluxEarth,
            ageGigayears: 0.01
        )
        let bondiRadiusEarth = resolvedBondiRadiusEarth(
            mass: initialComposition.totalMass,
            equilibriumTemperatureKelvin: equilibriumTemperatureKelvin
        )
        let contractedRadiusEarth = 0.1 * bondiRadiusEarth
        guard initialRadiusEarth > contractedRadiusEarth else {
            return initialGasEarth
        }
        let unboundFraction = min(
            0.9,
            1 - contractedRadiusEarth / max(initialRadiusEarth, 1e-8)
        )
        return max(0, initialGasEarth - initialGasEarth * unboundFraction)
    }

    private func retainedGasAfterCorePoweredLoss(
        _ gasEarth: Double,
        solidMassEarth: Double,
        equilibriumTemperatureKelvin: Double
    ) -> Double {
        guard gasEarth > 0 else {
            return 0
        }
        let vulnerableGasToCoreRatio = min(
            0.05,
            0.015
                * pow(max(equilibriumTemperatureKelvin / 1_000, 0.05), 1.5)
                * pow(max(solidMassEarth / 5, 0.002), -0.5)
        )
        return max(0, gasEarth - solidMassEarth * vulnerableGasToCoreRatio)
    }

    private func resolvedBondiRadiusEarth(
        mass: AstronomicalMass,
        equilibriumTemperatureKelvin: Double
    ) -> Double {
        let thermalEnergy = Self.boltzmannConstant * max(equilibriumTemperatureKelvin, 30)
        let radiusMeters = Self.gravitationalConstant
            * mass.kilograms
            * Self.hydrogenHeliumMeanMolecularMassKilograms
            / thermalEnergy
        return AstronomicalDistance(meters: radiusMeters).earthRadii
    }

    private func historicXUVLuminosityFraction(
        at ageGigayears: Double,
        finalAgeGigayears: Double,
        around star: GeneratedStar
    ) -> Double {
        min(
            1e-3,
            star.xuvLuminosityFraction
                * pow(max(ageGigayears / finalAgeGigayears, 0.002), -1.2)
        )
    }

    private func energyLimitedLossEarthMasses(
        massEarth: Double,
        radiusEarth: Double,
        incidentFluxEarth: Double,
        xuvLuminosityFraction: Double,
        durationGigayears: Double
    ) -> Double {
        guard policy.atmosphereEscapeEfficiency > 0,
              xuvLuminosityFraction > 0,
              durationGigayears > 0 else {
            return 0
        }
        let mass = AstronomicalMass(earthMasses: massEarth)
        let radius = AstronomicalDistance(earthRadii: radiusEarth)
        let duration = AstronomicalDuration(gigayears: durationGigayears)
        let xuvFlux = Self.terrestrialBolometricFluxWattsPerSquareMeter
            * max(incidentFluxEarth, 0)
            * xuvLuminosityFraction
        let lossKilograms = policy.atmosphereEscapeEfficiency
            * Double.pi
            * pow(radius.meters, 3)
            * xuvFlux
            * duration.seconds
            / (Self.gravitationalConstant * mass.kilograms)
        guard lossKilograms.isFinite else {
            return .greatestFiniteMagnitude
        }
        return AstronomicalMass(kilograms: max(0, lossKilograms)).earthMasses
    }
}
