import Testing
@testable import Engine2

nonisolated struct AstronomicalQuantityTests {
    @Test func massConversionsPreserveNamedUnits() {
        let earthMass = AstronomicalMass(earthMasses: 1)
        let solarMass = AstronomicalMass(solarMasses: 1)

        #expect(abs(earthMass.earthMasses - 1) < 1e-15)
        #expect(abs(solarMass.solarMasses - 1) < 1e-15)
        #expect(abs(solarMass.earthMasses - 332_954.3552) < 0.1)
        #expect(earthMass == .earth)
        #expect(solarMass == .sun)
    }

    @Test func distanceConversionsSeparatePlanetaryAndStellarScales() {
        let astronomicalUnit = AstronomicalDistance(astronomicalUnits: 1)
        let earthRadius = AstronomicalDistance(earthRadii: 1)
        let solarRadius = AstronomicalDistance(solarRadii: 1)

        #expect(abs(astronomicalUnit.astronomicalUnits - 1) < 1e-15)
        #expect(abs(earthRadius.earthRadii - 1) < 1e-15)
        #expect(abs(solarRadius.solarRadii - 1) < 1e-15)
        #expect(earthRadius < solarRadius)
        #expect(solarRadius < astronomicalUnit)
    }

    @Test func astronomicalDurationsKeepFormationAndPresentAgeDistinct() {
        let diskLifetime = AstronomicalDuration(megayears: 3)
        let systemAge = AstronomicalDuration(gigayears: 4.5)

        #expect(abs(diskLifetime.megayears - 3) < 1e-15)
        #expect(abs(systemAge.gigayears - 4.5) < 1e-15)
        #expect(diskLifetime < systemAge)
    }

    @Test func luminosityAndPressureConversionsPreserveNamedUnits() {
        let solarLuminosity = StellarLuminosity(solarLuminosities: 1)
        let bar = SurfacePressure(bars: 1)

        #expect(solarLuminosity == .solarLuminosity)
        #expect(bar == .bar)
        #expect(solarLuminosity.solarLuminosities == 1)
        #expect(bar.bars == 1)
    }
}
