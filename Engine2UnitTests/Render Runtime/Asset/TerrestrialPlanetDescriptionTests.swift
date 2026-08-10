import Testing
@testable import Engine2

struct TerrestrialPlanetDescriptionTests {
    private static let description = TerrestrialPlanetDescription(
        surfaceRecipe: .blueMarble,
        surfaceRadius: 1,
        surfaceNormalStrength: 0.35,
        cloudRadius: 1.05,
        atmosphereRadius: 1.10,
        cloudOpacity: 0.82,
        atmosphereIntensity: 0.75,
        cloudShadowStrength: 0.65
    )

    @Test func preservesEveryAuthoredRecipeAndParameter() {
        let description = Self.description

        #expect(description.surfaceRecipe == .blueMarble)
        #expect(description.surfaceRadius == 1)
        #expect(description.surfaceNormalStrength == 0.35)
        #expect(description.cloudRadius == 1.05)
        #expect(description.atmosphereRadius == 1.10)
        #expect(description.cloudOpacity == 0.82)
        #expect(description.atmosphereIntensity == 0.75)
        #expect(description.cloudShadowStrength == 0.65)
    }

    @Test func radiusValidationRequiresFiniteOrderedNestedShells() {
        #expect(
            TerrestrialPlanetDescription.acceptsRadii(
                surfaceRadius: 1,
                cloudRadius: 1.05,
                atmosphereRadius: 1.10
            )
        )
        #expect(
            !TerrestrialPlanetDescription.acceptsRadii(
                surfaceRadius: 0,
                cloudRadius: 1.05,
                atmosphereRadius: 1.10
            )
        )
        #expect(
            !TerrestrialPlanetDescription.acceptsRadii(
                surfaceRadius: 1,
                cloudRadius: 1,
                atmosphereRadius: 1.10
            )
        )
        #expect(
            !TerrestrialPlanetDescription.acceptsRadii(
                surfaceRadius: 1,
                cloudRadius: 1.05,
                atmosphereRadius: 1.05
            )
        )
        #expect(
            !TerrestrialPlanetDescription.acceptsRadii(
                surfaceRadius: .nan,
                cloudRadius: 1.05,
                atmosphereRadius: 1.10
            )
        )
    }

    @Test func scalarValidationRejectsOutOfRangeAndNonfiniteValues() {
        #expect(TerrestrialPlanetDescription.acceptsUnitFactor(0))
        #expect(TerrestrialPlanetDescription.acceptsUnitFactor(1))
        #expect(!TerrestrialPlanetDescription.acceptsUnitFactor(-0.001))
        #expect(!TerrestrialPlanetDescription.acceptsUnitFactor(1.001))
        #expect(!TerrestrialPlanetDescription.acceptsUnitFactor(.nan))
        #expect(!TerrestrialPlanetDescription.acceptsUnitFactor(.infinity))

        #expect(TerrestrialPlanetDescription.acceptsNonnegativeFactor(0))
        #expect(TerrestrialPlanetDescription.acceptsNonnegativeFactor(10))
        #expect(!TerrestrialPlanetDescription.acceptsNonnegativeFactor(-0.001))
        #expect(!TerrestrialPlanetDescription.acceptsNonnegativeFactor(.nan))
        #expect(!TerrestrialPlanetDescription.acceptsNonnegativeFactor(.infinity))
    }
}
