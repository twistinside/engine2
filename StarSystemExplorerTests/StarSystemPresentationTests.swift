import Testing

@testable import StarSystemExplorer

nonisolated struct StarSystemPresentationTests {
    private let presentation = StarSystemPresentation()

    @Test func smallNonzeroValuesKeepSignificantDigits() {
        #expect(presentation.number(0.003_702_9) == "0.0037")
        #expect(presentation.number(0.001_561_5) == "0.00156")
        #expect(presentation.number(0.004_228_8) == "0.00423")
    }

    @Test func resolvedPlanetRangeDescribesEmptyAndPopulatedSystems() {
        #expect(presentation.resolvedPlanetRangeLabel(count: 0) == "No resolved planets")
        #expect(presentation.resolvedPlanetRangeLabel(count: 1) == "P1…P1")
        #expect(presentation.resolvedPlanetRangeLabel(count: 9) == "P1…P9")
    }

    @Test func classificationHelpExplainsEveryBadgeVariant() {
        #expect(presentation.classificationHelp(for: PlanetaryBulkRegime.metalRich).contains("38%"))
        #expect(presentation.classificationHelp(for: PlanetaryBulkRegime.rocky).contains("Rock and metal"))
        #expect(presentation.classificationHelp(for: PlanetaryBulkRegime.volatileRich).contains("25%"))
        #expect(presentation.classificationHelp(for: PlanetaryBulkRegime.hydrogenHeliumDominated).contains("half"))

        #expect(presentation.classificationHelp(for: PlanetaryVisibleBoundary.exposedSolid).contains("solid surface"))
        #expect(presentation.classificationHelp(for: PlanetaryVisibleBoundary.opaqueAtmosphere).contains("hides"))

        #expect(presentation.classificationHelp(for: PlanetaryAtmosphereRegime.airless).contains("No resolved"))
        #expect(presentation.classificationHelp(for: PlanetaryAtmosphereRegime.tenuous).contains("below 0.05 bar"))
        #expect(presentation.classificationHelp(for: PlanetaryAtmosphereRegime.secondary).contains("at least 0.05 bar"))
        #expect(presentation.classificationHelp(for: PlanetaryAtmosphereRegime.deepEnvelope).contains("opaque"))

        #expect(presentation.classificationHelp(for: PlanetaryThermalRegime.frozen).contains("below 240 K"))
        #expect(presentation.classificationHelp(for: PlanetaryThermalRegime.temperate).contains("240 K through 350 K"))
        #expect(presentation.classificationHelp(for: PlanetaryThermalRegime.hot).contains("above 350 K"))
        #expect(presentation.classificationHelp(for: PlanetaryThermalRegime.molten).contains("at least 1,200 K"))

        #expect(presentation.classificationHelp(for: PlanetaryWaterRegime.dry).contains("negligible or absent"))
        #expect(presentation.classificationHelp(for: PlanetaryWaterRegime.iceCovered).contains("surface ice"))
        #expect(presentation.classificationHelp(for: PlanetaryWaterRegime.partialLiquid).contains("less than 80%"))
        #expect(presentation.classificationHelp(for: PlanetaryWaterRegime.globalOcean).contains("at least 80%"))
        #expect(presentation.classificationHelp(for: PlanetaryWaterRegime.steam).contains("exceeds 373 K"))
        #expect(presentation.classificationHelp(for: PlanetaryWaterRegime.inaccessible).contains("prevents"))
    }
}
