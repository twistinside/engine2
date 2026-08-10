import Testing
@testable import Engine2

struct TerrestrialPlanetDescriptionTests {
    private static let description = TerrestrialPlanetDescription(
        elevationTextureID: .terrestrialPlanetElevation,
        surfaceTextureID: .terrestrialPlanetSurface,
        controlTextureID: .terrestrialPlanetControl,
        cloudTextureID: .terrestrialPlanetClouds,
        surfaceRadius: 1,
        maximumRelief: 0.035,
        seaLevel: 0.5,
        cloudRadius: 1.05,
        atmosphereRadius: 1.10,
        cloudOpacity: 0.82,
        atmosphereIntensity: 0.75,
        cloudShadowStrength: 0.65
    )

    @Test func preservesEveryAuthoredTextureAndParameter() {
        let description = Self.description

        #expect(
            description.requiredTextureIDs == [
                .terrestrialPlanetElevation,
                .terrestrialPlanetSurface,
                .terrestrialPlanetControl,
                .terrestrialPlanetClouds
            ]
        )
        #expect(description.surfaceRadius == 1)
        #expect(description.maximumRelief == 0.035)
        #expect(description.seaLevel == 0.5)
        #expect(description.cloudRadius == 1.05)
        #expect(description.atmosphereRadius == 1.10)
        #expect(description.cloudOpacity == 0.82)
        #expect(description.atmosphereIntensity == 0.75)
        #expect(description.cloudShadowStrength == 0.65)
    }

    @Test func textureValidationRequiresOneDistinctAssetPerRole() {
        #expect(
            TerrestrialPlanetDescription.acceptsDistinctTextureIDs(
                elevationTextureID: .terrestrialPlanetElevation,
                surfaceTextureID: .terrestrialPlanetSurface,
                controlTextureID: .terrestrialPlanetControl,
                cloudTextureID: .terrestrialPlanetClouds
            )
        )
        #expect(
            !TerrestrialPlanetDescription.acceptsDistinctTextureIDs(
                elevationTextureID: .terrestrialPlanetElevation,
                surfaceTextureID: .terrestrialPlanetElevation,
                controlTextureID: .terrestrialPlanetControl,
                cloudTextureID: .terrestrialPlanetClouds
            )
        )
    }

    @Test func radiusValidationRequiresFiniteOrderedNestedShells() {
        #expect(
            TerrestrialPlanetDescription.acceptsRadii(
                surfaceRadius: 1,
                maximumRelief: 0.035,
                cloudRadius: 1.05,
                atmosphereRadius: 1.10
            )
        )
        #expect(
            !TerrestrialPlanetDescription.acceptsRadii(
                surfaceRadius: 0,
                maximumRelief: 0.035,
                cloudRadius: 1.05,
                atmosphereRadius: 1.10
            )
        )
        #expect(
            !TerrestrialPlanetDescription.acceptsRadii(
                surfaceRadius: 1,
                maximumRelief: -0.001,
                cloudRadius: 1.05,
                atmosphereRadius: 1.10
            )
        )
        #expect(
            !TerrestrialPlanetDescription.acceptsRadii(
                surfaceRadius: 1,
                maximumRelief: 0.05,
                cloudRadius: 1.05,
                atmosphereRadius: 1.10
            )
        )
        #expect(
            !TerrestrialPlanetDescription.acceptsRadii(
                surfaceRadius: 1,
                maximumRelief: 0.035,
                cloudRadius: 1.05,
                atmosphereRadius: 1.05
            )
        )
        #expect(
            !TerrestrialPlanetDescription.acceptsRadii(
                surfaceRadius: .nan,
                maximumRelief: 0.035,
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
