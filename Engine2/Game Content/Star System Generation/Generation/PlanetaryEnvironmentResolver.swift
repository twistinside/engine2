import Foundation

/// Resolves bounded post-disk atmosphere evolution, radius, zero-dimensional climate, and physical state.
///
/// The resolver conserves primordial hydrogen and helium by returning every
/// removed mass to the caller's escaped-gas ledger. Secondary atmosphere is a
/// finite phase projection within the body's solid volatile reservoirs. Complete
/// stripping remains exactly zero so the airless classification has no epsilon
/// threshold. This phase never assigns gameplay value, habitability, life, or
/// an authored appearance.
nonisolated struct PlanetaryEnvironmentResolver: Sendable {
    let policy: StarSystemGenerationPolicy
    private let radiusResolver: PlanetaryRadiusResolver
    private let primordialAtmosphereEvolver: PrimordialAtmosphereEvolver
    private let secondaryAtmosphereResolver: SecondaryAtmosphereResolver

    init(policy: StarSystemGenerationPolicy) {
        let radiusResolver = PlanetaryRadiusResolver()
        self.policy = policy
        self.radiusResolver = radiusResolver
        self.primordialAtmosphereEvolver = PrimordialAtmosphereEvolver(
            policy: policy,
            radiusResolver: radiusResolver
        )
        self.secondaryAtmosphereResolver = SecondaryAtmosphereResolver()
    }

    func resolve(
        composition initialComposition: CelestialMassComposition,
        orbit: KeplerianOrbit,
        around star: GeneratedStar
    ) -> EvolvedPlanetaryBody {
        let incidentFlux = meanIncidentFluxEarth(orbit: orbit, star: star)
        let retainedComposition = primordialAtmosphereEvolver.evolve(
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
        let radiusEarth = radiusResolver.resolveVisibleRadiusEarth(
            composition: composition,
            incidentFluxEarth: incidentFlux,
            ageGigayears: star.age.gigayears
        )
        let solidRadiusEarth = radiusResolver.resolveSolidRadiusEarth(composition: composition)
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
        let secondaryAtmosphereEarth = secondaryAtmosphereResolver.atmosphereMassEarth(
            composition: composition,
            massEarth: massEarth,
            solidRadiusEarth: solidRadiusEarth,
            incidentFluxEarth: incidentFluxEarth
        )
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
        return environment.atmosphereMass == .zero ? .airless : .tenuous
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
        if environment.liquidWaterCoverage > 0 {
            return .partialLiquid
        }
        return environment.waterIceCoverage > 0 ? .iceCovered : .dry
    }

    private func meanIncidentFluxEarth(orbit: KeplerianOrbit, star: GeneratedStar) -> Double {
        let semiMajorAxisAU = orbit.semiMajorAxis.astronomicalUnits
        let eccentricity = orbit.eccentricity.rawValue
        return star.luminosity.solarLuminosities
            / (semiMajorAxisAU * semiMajorAxisAU * sqrt(1 - eccentricity * eccentricity))
    }
}
