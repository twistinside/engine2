import Foundation
import Testing
@testable import Engine2

struct TextureAssetReferenceTests {
    @Test func preservesTheExactFileURLAndColorInterpretation() {
        let resourceURL = URL(fileURLWithPath: "/tmp/TerrestrialPlanetSurface.png")
        let reference = TextureAssetReference(
            resourceURL: resourceURL,
            interpretation: .sRGB
        )

        #expect(reference.resourceURL == resourceURL)
        #expect(reference.interpretation == .sRGB)
    }

    @Test func distinguishesColorFromNumericData() {
        #expect(TextureAssetInterpretation.sRGB != .linear)
    }
}
