import Foundation
import Testing
@testable import Engine2

struct ModelAssetReferenceTests {
    @Test func preservesAnExactFileURLAndDeclaredFormat() {
        let resourceURL = URL(fileURLWithPath: "/tmp/TerrestrialPlanet.usda")
        let reference = ModelAssetReference(
            resourceURL: resourceURL,
            format: .usda
        )

        #expect(reference.resourceURL == resourceURL)
        #expect(reference.resourceName == "TerrestrialPlanet")
        #expect(reference.format == .usda)
    }

    @Test func supportsEveryDeclaredModelFormat() {
        #expect(ModelAssetFormat.usda.rawValue == "usda")
        #expect(ModelAssetFormat.usdz.rawValue == "usdz")
    }
}
