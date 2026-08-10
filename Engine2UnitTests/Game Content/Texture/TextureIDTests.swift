import Foundation
import Testing
@testable import Engine2

struct TextureIDTests {
    @Test func allCasesPreservesTheExhaustiveContentVocabulary() {
        #expect(
            TextureID.allCases == [
                .terrestrialPlanetElevation,
                .terrestrialPlanetSurface,
                .terrestrialPlanetControl,
                .terrestrialPlanetClouds
            ]
        )
    }

    @Test func codableRoundTripPreservesEveryGameContentIdentity() throws {
        let original = TextureID.allCases

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode([TextureID].self, from: data)

        #expect(decoded == original)
    }
}
