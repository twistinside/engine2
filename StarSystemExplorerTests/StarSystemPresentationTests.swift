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
}
