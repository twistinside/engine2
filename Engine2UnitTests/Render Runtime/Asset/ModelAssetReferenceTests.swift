import Foundation
import Testing
@testable import Engine2

struct ModelAssetReferenceTests {
    @Test func preservesAnExactFileURLAndDeclaredFormat() {
        let resourceURL = URL(fileURLWithPath: "/tmp/Ball.usdz")
        let reference = ModelAssetReference(
            resourceURL: resourceURL,
            format: .usdz
        )

        #expect(reference.resourceURL == resourceURL)
        #expect(reference.resourceName == "Ball")
        #expect(reference.format == .usdz)
    }

    @Test func supportsEveryDeclaredModelFormat() {
        #expect(ModelAssetFormat.usdz.rawValue == "usdz")
    }
}
