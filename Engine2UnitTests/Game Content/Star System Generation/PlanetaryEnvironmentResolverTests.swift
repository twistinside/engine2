import Foundation
import Testing
@testable import Engine2

nonisolated struct PlanetaryEnvironmentResolverTests {
    private let policy = StarSystemGenerationPolicy.coreAccretionLiteV1

    @Test func visibleRadiusNeverFallsInsideTheSolidBody() {
        let resolver = PlanetaryRadiusResolver()
        let composition = CelestialMassComposition(
            iron: AstronomicalMass(earthMasses: 2_000),
            silicate: AstronomicalMass(earthMasses: 3_000),
            water: .zero,
            otherVolatiles: .zero,
            hydrogenHelium: AstronomicalMass(earthMasses: 100)
        )

        let solidRadius = resolver.resolveSolidRadiusEarth(composition: composition)
        let visibleRadius = resolver.resolveVisibleRadiusEarth(
            composition: composition,
            incidentFluxEarth: 1,
            ageGigayears: 5
        )

        #expect(visibleRadius >= solidRadius)
    }

    @Test func distanceAndLuminosityCausallyChangeFluxAndTemperature() {
        let resolver = PlanetaryEnvironmentResolver(policy: policy)
        let composition = rockyComposition(solidMassEarth: 1, hydrogenHeliumEarth: 0)
        let baselineStar = MainSequenceStarGenerator(policy: policy).generate(
            seed: StarSystemSeed(rawValue: 41)
        )
        let brightStar = replacingLuminosity(
            of: baselineStar,
            with: baselineStar.luminosity.solarLuminosities * 2
        )
        let nearOrbit = orbit(astronomicalUnits: 1)
        let farOrbit = orbit(astronomicalUnits: 2)

        let near = resolver.resolvePresentBody(
            composition: composition,
            orbit: nearOrbit,
            around: baselineStar
        )
        let far = resolver.resolvePresentBody(
            composition: composition,
            orbit: farOrbit,
            around: baselineStar
        )
        let bright = resolver.resolvePresentBody(
            composition: composition,
            orbit: nearOrbit,
            around: brightStar
        )

        #expect(relativeDifference(far.environment.incidentFluxEarth, near.environment.incidentFluxEarth / 4) < 1e-12)
        #expect(far.environment.equilibriumTemperature < near.environment.equilibriumTemperature)
        #expect(bright.environment.incidentFluxEarth > near.environment.incidentFluxEarth)
        #expect(bright.environment.equilibriumTemperature > near.environment.equilibriumTemperature)
    }

    @Test func greaterXUVExposureReducesRetainedPrimordialGas() {
        let resolver = PlanetaryEnvironmentResolver(policy: policy)
        let initial = rockyComposition(solidMassEarth: 3, hydrogenHeliumEarth: 0.3)
        let baselineStar = MainSequenceStarGenerator(policy: policy).generate(
            seed: StarSystemSeed(rawValue: 42)
        )
        let quietStar = replacingXUVFraction(of: baselineStar, with: 1e-7)
        let activeStar = replacingXUVFraction(of: baselineStar, with: 1e-3)
        let orbit = orbit(astronomicalUnits: 0.2)

        let quiet = resolver.resolve(composition: initial, orbit: orbit, around: quietStar)
        let active = resolver.resolve(composition: initial, orbit: orbit, around: activeStar)

        #expect(
            active.composition.hydrogenHelium.earthMasses
                < quiet.composition.hydrogenHelium.earthMasses
        )
    }

    @Test func greaterGravityIncreasesRetainedEnvelopeFraction() {
        let resolver = PlanetaryEnvironmentResolver(policy: policy)
        let star = MainSequenceStarGenerator(policy: policy).generate(
            seed: StarSystemSeed(rawValue: 43)
        )
        let orbit = orbit(astronomicalUnits: 0.3)
        let lowMass = rockyComposition(solidMassEarth: 1, hydrogenHeliumEarth: 0.1)
        let highMass = rockyComposition(solidMassEarth: 5, hydrogenHeliumEarth: 0.5)

        let evolvedLow = resolver.resolve(composition: lowMass, orbit: orbit, around: star)
        let evolvedHigh = resolver.resolve(composition: highMass, orbit: orbit, around: star)
        let lowRetention = evolvedLow.composition.hydrogenHelium.earthMasses
            / lowMass.hydrogenHelium.earthMasses
        let highRetention = evolvedHigh.composition.hydrogenHelium.earthMasses
            / highMass.hydrogenHelium.earthMasses

        #expect(highRetention > lowRetention)
    }

    @Test func completePrimordialLossProducesAnExactlyAirlessBody() {
        let resolver = PlanetaryEnvironmentResolver(policy: policy)
        let initial = rockyComposition(solidMassEarth: 1, hydrogenHeliumEarth: 1e-7)
        let baselineStar = MainSequenceStarGenerator(policy: policy).generate(
            seed: StarSystemSeed(rawValue: 46)
        )
        let activeStar = replacingXUVFraction(of: baselineStar, with: 1e-3)

        let evolved = resolver.resolve(
            composition: initial,
            orbit: orbit(astronomicalUnits: 0.03),
            around: activeStar
        )

        #expect(evolved.composition.hydrogenHelium == .zero)
        #expect(evolved.escapedHydrogenHeliumMass == initial.hydrogenHelium)
        #expect(evolved.environment.atmosphereMass == .zero)
        #expect(evolved.environment.surfacePressure?.bars == 0)
        #expect(evolved.physicalState.atmosphere == .airless)
    }

    @Test func cosmicShorelineCanRemoveTheCompleteSecondaryAtmosphere() {
        let resolver = PlanetaryEnvironmentResolver(policy: policy)
        let composition = rockyComposition(solidMassEarth: 1, hydrogenHeliumEarth: 0)
        let sampledStar = MainSequenceStarGenerator(policy: policy).generate(
            seed: StarSystemSeed(rawValue: 47)
        )
        let star = replacingLuminosity(of: sampledStar, with: 1)

        let irradiated = resolver.resolvePresentBody(
            composition: composition,
            orbit: orbit(astronomicalUnits: 0.05),
            around: star
        )
        let temperate = resolver.resolvePresentBody(
            composition: composition,
            orbit: orbit(astronomicalUnits: 1),
            around: star
        )

        #expect(irradiated.environment.atmosphereMass == .zero)
        #expect(irradiated.physicalState.atmosphere == .airless)
        #expect(temperate.environment.atmosphereMass > .zero)
        #expect(temperate.physicalState.atmosphere == .secondary)
    }

    @Test func anyPositiveAtmosphereMassIsNotClassifiedAsAirless() {
        let resolver = PlanetaryEnvironmentResolver(policy: policy)
        let star = replacingLuminosity(
            of: MainSequenceStarGenerator(policy: policy).generate(
                seed: StarSystemSeed(rawValue: 48)
            ),
            with: 1
        )
        let composition = CelestialMassComposition(
            iron: AstronomicalMass(earthMasses: 0.32),
            silicate: AstronomicalMass(earthMasses: 0.68 - 1e-10),
            water: .zero,
            otherVolatiles: AstronomicalMass(earthMasses: 1e-10),
            hydrogenHelium: .zero
        )

        let body = resolver.resolvePresentBody(
            composition: composition,
            orbit: orbit(astronomicalUnits: 1),
            around: star
        )

        #expect(body.environment.atmosphereMass > .zero)
        #expect(body.environment.surfacePressure?.bars ?? 0 < 0.05)
        #expect(body.physicalState.atmosphere == .tenuous)
    }

    @Test func opaqueAtmospheresPublishNoExposedSurfacePressureOrWaterCoverage() {
        let resolver = PlanetaryEnvironmentResolver(policy: policy)
        let star = MainSequenceStarGenerator(policy: policy).generate(
            seed: StarSystemSeed(rawValue: 44)
        )
        let composition = rockyComposition(solidMassEarth: 10, hydrogenHeliumEarth: 5)

        let body = resolver.resolvePresentBody(
            composition: composition,
            orbit: orbit(astronomicalUnits: 1),
            around: star
        )

        #expect(body.physicalState.visibleBoundary == .opaqueAtmosphere)
        #expect(body.physicalState.atmosphere == .deepEnvelope)
        #expect(body.physicalState.water == .inaccessible)
        #expect(body.environment.surfacePressure == nil)
        #expect(body.environment.liquidWaterCoverage == 0)
        #expect(body.environment.waterIceCoverage == 0)
    }

    @Test func warmLowPressureWaterInventoryDoesNotClaimSurfaceIce() {
        let resolver = PlanetaryEnvironmentResolver(policy: policy)
        let sampledStar = MainSequenceStarGenerator(policy: policy).generate(
            seed: StarSystemSeed(rawValue: 49)
        )
        let star = replacingLuminosity(of: sampledStar, with: 1)
        let composition = CelestialMassComposition(
            iron: AstronomicalMass(earthMasses: 0.32),
            silicate: AstronomicalMass(earthMasses: 0.679_989),
            water: AstronomicalMass(earthMasses: 0.000_011),
            otherVolatiles: .zero,
            hydrogenHelium: .zero
        )

        let body = resolver.resolvePresentBody(
            composition: composition,
            orbit: orbit(astronomicalUnits: 0.8),
            around: star
        )

        #expect((260...373).contains(body.environment.visibleBoundaryTemperature.kelvin))
        #expect(body.environment.surfacePressure?.bars ?? 0 < 0.006)
        #expect(body.environment.liquidWaterCoverage == 0)
        #expect(body.environment.waterIceCoverage == 0)
        #expect(body.physicalState.water == .dry)
    }

    @Test func storedEquilibriumTemperatureUsesTheStoredFinalAlbedo() {
        let resolver = PlanetaryEnvironmentResolver(policy: policy)
        let star = MainSequenceStarGenerator(policy: policy).generate(
            seed: StarSystemSeed(rawValue: 45)
        )
        let body = resolver.resolvePresentBody(
            composition: rockyComposition(solidMassEarth: 1, hydrogenHeliumEarth: 0),
            orbit: orbit(astronomicalUnits: 1),
            around: star
        )
        let environment = body.environment
        let expected = 278.5
            * pow(
                environment.incidentFluxEarth * (1 - environment.bondAlbedo),
                0.25
            )

        #expect(relativeDifference(environment.equilibriumTemperature.kelvin, expected) < 1e-12)
    }

    private func rockyComposition(
        solidMassEarth: Double,
        hydrogenHeliumEarth: Double
    ) -> CelestialMassComposition {
        CelestialMassComposition(
            iron: AstronomicalMass(earthMasses: solidMassEarth * 0.32),
            silicate: AstronomicalMass(earthMasses: solidMassEarth * 0.63),
            water: AstronomicalMass(earthMasses: solidMassEarth * 0.04),
            otherVolatiles: AstronomicalMass(earthMasses: solidMassEarth * 0.01),
            hydrogenHelium: AstronomicalMass(earthMasses: hydrogenHeliumEarth)
        )
    }

    private func orbit(astronomicalUnits: Double) -> KeplerianOrbit {
        KeplerianOrbit(
            semiMajorAxis: AstronomicalDistance(astronomicalUnits: astronomicalUnits),
            eccentricity: .circular,
            inclinationDegrees: 0
        )
    }

    private func replacingLuminosity(
        of star: GeneratedStar,
        with luminositySolar: Double
    ) -> GeneratedStar {
        GeneratedStar(
            mass: star.mass,
            metallicityDex: star.metallicityDex,
            age: star.age,
            luminosity: StellarLuminosity(solarLuminosities: luminositySolar),
            radius: star.radius,
            effectiveTemperature: star.effectiveTemperature,
            activityRegime: star.activityRegime,
            xuvLuminosityFraction: star.xuvLuminosityFraction
        )
    }

    private func replacingXUVFraction(
        of star: GeneratedStar,
        with xuvLuminosityFraction: Double
    ) -> GeneratedStar {
        GeneratedStar(
            mass: star.mass,
            metallicityDex: star.metallicityDex,
            age: star.age,
            luminosity: star.luminosity,
            radius: star.radius,
            effectiveTemperature: star.effectiveTemperature,
            activityRegime: star.activityRegime,
            xuvLuminosityFraction: xuvLuminosityFraction
        )
    }

    private func relativeDifference(_ first: Double, _ second: Double) -> Double {
        abs(first - second) / max(abs(first), abs(second), 1)
    }
}
