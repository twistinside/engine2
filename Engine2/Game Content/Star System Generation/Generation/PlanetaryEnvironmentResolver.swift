import Foundation

/// Resolves present-day envelope loss, radius, zero-dimensional climate, and physical state.
///
/// This phase uses bounded regime approximations. It never assigns gameplay
/// value, habitability, life, or an authored appearance.
nonisolated struct PlanetaryEnvironmentResolver: Sendable {
    let policy: StarSystemGenerationPolicy

    func resolve(
        composition initialComposition: CelestialMassComposition,
        orbit: KeplerianOrbit,
        around star: GeneratedStar
    ) -> EvolvedPlanetaryBody {
        let incidentFlux = meanIncidentFluxEarth(orbit: orbit, star: star)
        let retainedComposition = evolvePrimordialEnvelope(
            initialComposition,
            incidentFluxEarth: incidentFlux,
            around: star
        )
        let escapedHydrogenHelium = max(
            0,
            initialComposition.hydrogenHelium.earthMasses
                - retainedComposition.hydrogenHelium.earthMasses
        )
        let presentBody = resolvePresentBody(
            composition: retainedComposition,
            orbit: orbit,
            around: star
        )
        return EvolvedPlanetaryBody(
            composition: presentBody.composition,
            radius: presentBody.radius,
            environment: presentBody.environment,
            physicalState: presentBody.physicalState,
            escapedHydrogenHeliumMass: AstronomicalMass(earthMasses: escapedHydrogenHelium)
        )
    }

    /// Recomputes present-day facts from a composition that has already completed escape evolution.
    func resolvePresentBody(
        composition: CelestialMassComposition,
        orbit: KeplerianOrbit,
        around star: GeneratedStar
    ) -> EvolvedPlanetaryBody {
        let incidentFlux = meanIncidentFluxEarth(orbit: orbit, star: star)
        let radiusEarth = resolvedRadiusEarth(
            composition: composition,
            incidentFluxEarth: incidentFlux,
            ageGigayears: star.age.gigayears
        )
        let solidRadiusEarth = resolvedSolidRadiusEarth(composition: composition)
        let climate = resolveClimate(
            composition: composition,
            massEarth: composition.totalMass.earthMasses,
            solidRadiusEarth: solidRadiusEarth,
            visibleRadiusEarth: radiusEarth,
            incidentFluxEarth: incidentFlux
        )
        let physicalState = derivePhysicalState(
            composition: composition,
            environment: climate
        )
        return EvolvedPlanetaryBody(
            composition: composition,
            radius: AstronomicalDistance(earthRadii: radiusEarth),
            environment: climate,
            physicalState: physicalState,
            escapedHydrogenHeliumMass: .zero
        )
    }

    private func evolvePrimordialEnvelope(
        _ initialComposition: CelestialMassComposition,
        incidentFluxEarth: Double,
        around star: GeneratedStar
    ) -> CelestialMassComposition {
        var retainedGas = initialComposition.hydrogenHelium.earthMasses
        guard retainedGas > 0 else {
            return initialComposition
        }
        let finalAgeGigayears = max(star.age.gigayears, 0.02)
        let logarithmicSpan = log(finalAgeGigayears / 0.01)
        let presentXUVFactor = star.xuvLuminosityFraction / 1e-5

        for step in 0..<policy.evolutionStepCount {
            let lowerFraction = Double(step) / Double(policy.evolutionStepCount)
            let upperFraction = Double(step + 1) / Double(policy.evolutionStepCount)
            let lowerAge = 0.01 * exp(logarithmicSpan * lowerFraction)
            let upperAge = 0.01 * exp(logarithmicSpan * upperFraction)
            let middleAge = sqrt(lowerAge * upperAge)
            let currentComposition = initialComposition.replacingHydrogenHelium(
                with: AstronomicalMass(earthMasses: retainedGas)
            )
            let radiusEarth = resolvedRadiusEarth(
                composition: currentComposition,
                incidentFluxEarth: incidentFluxEarth,
                ageGigayears: middleAge
            )
            let massEarth = currentComposition.totalMass.earthMasses
            let historicXUVFactor = min(
                100,
                presentXUVFactor
                    * pow(max(middleAge / finalAgeGigayears, 0.002), -1.2)
            )
            let binding = massEarth * massEarth
                / max(
                    pow(radiusEarth, 3)
                        * max(incidentFluxEarth, 1e-6)
                        * historicXUVFactor,
                    1e-9
                )
            let epochWeight = (upperAge - lowerAge) / finalAgeGigayears
            let lossExponent = policy.atmosphereEscapeEfficiency
                * epochWeight * 80 / (binding + 2)
            retainedGas *= exp(-min(lossExponent, 4))
        }
        if retainedGas < 1e-12 {
            retainedGas = 0
        }
        return initialComposition.replacingHydrogenHelium(
            with: AstronomicalMass(earthMasses: retainedGas)
        )
    }

    private func resolvedRadiusEarth(
        composition: CelestialMassComposition,
        incidentFluxEarth: Double,
        ageGigayears: Double
    ) -> Double {
        let solidRadius = resolvedSolidRadiusEarth(composition: composition)
        let totalMass = composition.totalMass.earthMasses
        let envelopeFraction = composition.hydrogenHeliumMassFraction
        guard envelopeFraction > 1e-5 else {
            return max(solidRadius, 0.03)
        }
        if envelopeFraction >= 0.5 && totalMass >= 30 {
            return min(14, max(8, 10.5 + 0.6 * log10(max(totalMass / 100, 0.1))))
        }
        let envelopeInflation = 2.2
            * pow(max(envelopeFraction / 0.05, 1e-4), 0.25)
            * pow(max(totalMass / 5, 0.1), -0.10)
            * pow(max(incidentFluxEarth, 0.01), 0.04)
            * pow(max(ageGigayears / 5, 0.02), -0.08)
        return min(10, max(solidRadius, solidRadius + envelopeInflation))
    }

    private func resolvedSolidRadiusEarth(composition: CelestialMassComposition) -> Double {
        let solidMass = max(composition.solidMass.earthMasses, 1e-8)
        let waterFraction = composition.waterMassFraction
        let otherVolatileFraction = composition.otherVolatiles.earthMasses / solidMass
        return max(
            0.03,
            pow(solidMass, 0.27)
                * (1 + 0.25 * waterFraction + 0.10 * otherVolatileFraction)
        )
    }

    private func resolveClimate(
        composition: CelestialMassComposition,
        massEarth: Double,
        solidRadiusEarth: Double,
        visibleRadiusEarth: Double,
        incidentFluxEarth: Double
    ) -> PlanetaryEnvironment {
        let atmosphericBoundary = resolveAtmosphericBoundary(
            composition: composition,
            massEarth: massEarth,
            solidRadiusEarth: solidRadiusEarth,
            visibleRadiusEarth: visibleRadiusEarth,
            incidentFluxEarth: incidentFluxEarth
        )
        let climate = solveClimate(
            incidentFluxEarth: incidentFluxEarth,
            opticalDepth: atmosphericBoundary.opticalDepth,
            waterFraction: composition.waterMassFraction,
            hasOpaqueAtmosphere: atmosphericBoundary.isOpaque
        )
        let coverage = waterCoverage(
            composition: composition,
            boundaryTemperatureKelvin: climate.visibleBoundaryTemperatureKelvin,
            pressureBars: atmosphericBoundary.climatePressureBars,
            hasOpaqueAtmosphere: atmosphericBoundary.isOpaque
        )
        return PlanetaryEnvironment(
            incidentFluxEarth: incidentFluxEarth,
            equilibriumTemperature: ThermodynamicTemperature(
                kelvin: climate.equilibriumTemperatureKelvin
            ),
            visibleBoundaryTemperature: ThermodynamicTemperature(
                kelvin: climate.visibleBoundaryTemperatureKelvin
            ),
            atmosphereMass: AstronomicalMass(
                earthMasses: atmosphericBoundary.atmosphereMassEarth
            ),
            surfacePressure: atmosphericBoundary.isOpaque
                ? nil
                : SurfacePressure(bars: atmosphericBoundary.exposedSurfacePressureBars),
            bondAlbedo: climate.bondAlbedo,
            liquidWaterCoverage: coverage.liquid,
            waterIceCoverage: coverage.ice
        )
    }

    private func resolveAtmosphericBoundary(
        composition: CelestialMassComposition,
        massEarth: Double,
        solidRadiusEarth: Double,
        visibleRadiusEarth: Double,
        incidentFluxEarth: Double
    ) -> PlanetaryAtmosphericBoundary {
        let escapeVelocityEarth = sqrt(max(massEarth / solidRadiusEarth, 1e-8))
        let shorelineIndex = 4 * log10(max(escapeVelocityEarth, 1e-5))
            - log10(max(incidentFluxEarth, 1e-6))
        let secondarySurvival = 1 / (1 + exp(-3 * (shorelineIndex + 0.25)))
        let geologicSupply = massEarth / (massEarth + 0.3)
        let accessibleVolatiles = composition.water.earthMasses
            + composition.otherVolatiles.earthMasses
        let secondaryAtmosphereEarth = accessibleVolatiles * 0.0001 * secondarySurvival * geologicSupply
        let atmosphereEarth = composition.hydrogenHelium.earthMasses + secondaryAtmosphereEarth
        let envelopeFraction = composition.hydrogenHeliumMassFraction
        let exposedSurfacePressureBars = atmosphereEarth / 8.62e-7
            * massEarth / max(pow(solidRadiusEarth, 4), 1e-8)
        let hasOpaqueAtmosphere = envelopeFraction >= 0.01
            || exposedSurfacePressureBars >= 100
        let visibleColumnPressureBars = atmosphereEarth / 8.62e-7
            * massEarth / max(pow(visibleRadiusEarth, 4), 1e-8)
        let climatePressureBars = hasOpaqueAtmosphere
            ? visibleColumnPressureBars
            : exposedSurfacePressureBars
        let opticalDepth = hasOpaqueAtmosphere
            ? min(60, 2 + 6 * log1p(max(climatePressureBars, 0)))
            : min(20, 0.7 * sqrt(max(climatePressureBars, 0)))
        return PlanetaryAtmosphericBoundary(
            atmosphereMassEarth: atmosphereEarth,
            exposedSurfacePressureBars: exposedSurfacePressureBars,
            climatePressureBars: climatePressureBars,
            opticalDepth: opticalDepth,
            isOpaque: hasOpaqueAtmosphere
        )
    }

    private func solveClimate(
        incidentFluxEarth: Double,
        opticalDepth: Double,
        waterFraction: Double,
        hasOpaqueAtmosphere: Bool
    ) -> PlanetaryClimateSolution {
        var albedo = 0.30
        var boundaryTemperatureKelvin = 0.0
        var equilibriumTemperatureKelvin = 0.0

        for _ in 0..<6 {
            equilibriumTemperatureKelvin = 278.5
                * pow(max(incidentFluxEarth * (1 - albedo), 0), 0.25)
            boundaryTemperatureKelvin = equilibriumTemperatureKelvin
                * pow(1 + 0.75 * opticalDepth, 0.25)
            albedo = resolvedAlbedo(
                temperatureKelvin: boundaryTemperatureKelvin,
                waterFraction: waterFraction,
                hasOpaqueAtmosphere: hasOpaqueAtmosphere
            )
        }
        equilibriumTemperatureKelvin = 278.5
            * pow(max(incidentFluxEarth * (1 - albedo), 0), 0.25)
        boundaryTemperatureKelvin = equilibriumTemperatureKelvin
            * pow(1 + 0.75 * opticalDepth, 0.25)
        return PlanetaryClimateSolution(
            equilibriumTemperatureKelvin: equilibriumTemperatureKelvin,
            visibleBoundaryTemperatureKelvin: boundaryTemperatureKelvin,
            bondAlbedo: albedo
        )
    }

    private func resolvedAlbedo(
        temperatureKelvin: Double,
        waterFraction: Double,
        hasOpaqueAtmosphere: Bool
    ) -> Double {
        if hasOpaqueAtmosphere {
            return temperatureKelvin < 180 ? 0.55 : 0.35
        }
        if waterFraction > 1e-4 && temperatureKelvin < 260 {
            return 0.60
        }
        if waterFraction > 1e-4 && temperatureKelvin < 360 {
            return 0.30
        }
        return temperatureKelvin > 900 ? 0.12 : 0.22
    }

    private func waterCoverage(
        composition: CelestialMassComposition,
        boundaryTemperatureKelvin: Double,
        pressureBars: Double,
        hasOpaqueAtmosphere: Bool
    ) -> PlanetaryWaterCoverage {
        guard !hasOpaqueAtmosphere else {
            return .none
        }
        let waterFraction = composition.waterMassFraction
        guard waterFraction >= 1e-5 else {
            return .none
        }
        let availableCoverage = min(1, waterFraction * 2_500)
        if boundaryTemperatureKelvin < 260 {
            return PlanetaryWaterCoverage(liquid: 0, ice: availableCoverage)
        }
        if boundaryTemperatureKelvin >= 273,
           boundaryTemperatureKelvin <= 373,
           pressureBars >= 0.006 {
            return PlanetaryWaterCoverage(
                liquid: availableCoverage,
                ice: max(0, 1 - availableCoverage) * 0.05
            )
        }
        return .none
    }

    private func derivePhysicalState(
        composition: CelestialMassComposition,
        environment: PlanetaryEnvironment
    ) -> PlanetaryPhysicalState {
        let bulk = bulkRegime(for: composition)
        let atmosphere = atmosphereRegime(for: environment)
        let temperature = environment.visibleBoundaryTemperature.kelvin
        let thermal = thermalRegime(temperatureKelvin: temperature)
        let water = waterRegime(
            composition: composition,
            environment: environment,
            atmosphere: atmosphere,
            temperatureKelvin: temperature
        )
        let boundary: PlanetaryVisibleBoundary = atmosphere == .deepEnvelope
            ? .opaqueAtmosphere
            : .exposedSolid
        return PlanetaryPhysicalState(
            bulk: bulk,
            visibleBoundary: boundary,
            atmosphere: atmosphere,
            thermal: thermal,
            water: water
        )
    }

    private func bulkRegime(
        for composition: CelestialMassComposition
    ) -> PlanetaryBulkRegime {
        let solidMass = max(composition.solidMass.earthMasses, 1e-12)
        let ironFraction = composition.iron.earthMasses / solidMass
        let volatileFraction = (composition.water.earthMasses + composition.otherVolatiles.earthMasses) / solidMass
        let envelopeFraction = composition.hydrogenHeliumMassFraction
        if envelopeFraction >= 0.5 {
            return .hydrogenHeliumDominated
        }
        if volatileFraction >= 0.25 {
            return .volatileRich
        }
        return ironFraction >= 0.38 ? .metalRich : .rocky
    }

    private func atmosphereRegime(
        for environment: PlanetaryEnvironment
    ) -> PlanetaryAtmosphereRegime {
        let pressureBars = environment.surfacePressure?.bars ?? 0
        if environment.surfacePressure == nil {
            return .deepEnvelope
        }
        if pressureBars >= 0.05 {
            return .secondary
        }
        return pressureBars >= 1e-5 ? .tenuous : .airless
    }

    private func thermalRegime(
        temperatureKelvin: Double
    ) -> PlanetaryThermalRegime {
        if temperatureKelvin >= 1_200 {
            return .molten
        }
        if temperatureKelvin > 350 {
            return .hot
        }
        return temperatureKelvin >= 240 ? .temperate : .frozen
    }

    private func waterRegime(
        composition: CelestialMassComposition,
        environment: PlanetaryEnvironment,
        atmosphere: PlanetaryAtmosphereRegime,
        temperatureKelvin: Double
    ) -> PlanetaryWaterRegime {
        if atmosphere == .deepEnvelope {
            return .inaccessible
        }
        if composition.waterMassFraction < 1e-5 {
            return .dry
        }
        if temperatureKelvin > 373 {
            return .steam
        }
        if environment.liquidWaterCoverage >= 0.80 {
            return .globalOcean
        }
        return environment.liquidWaterCoverage > 0 ? .partialLiquid : .iceCovered
    }

    private func meanIncidentFluxEarth(orbit: KeplerianOrbit, star: GeneratedStar) -> Double {
        let semiMajorAxisAU = orbit.semiMajorAxis.astronomicalUnits
        let eccentricity = orbit.eccentricity.rawValue
        return star.luminosity.solarLuminosities
            / (semiMajorAxisAU * semiMajorAxisAU * sqrt(1 - eccentricity * eccentricity))
    }
}
