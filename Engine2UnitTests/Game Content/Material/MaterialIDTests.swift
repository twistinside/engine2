import Foundation
import Testing
@testable import Engine2

struct MaterialIDTests {
    @Test func allCasesPreservesTheExhaustiveContentVocabulary() {
        // Catalog preflight uses this exhaustive order when reporting missing
        // authored descriptions. It also mirrors the validation scene's
        // dielectric row followed by its metal row.
        #expect(
            MaterialID.allCases == [
                .warmDielectricSmooth,
                .warmDielectric,
                .warmDielectricRough,
                .goldMetalSmooth,
                .goldMetal,
                .goldMetalRough
            ]
        )
    }

    @Test func codableRoundTripPreservesEveryGameContentIdentity() throws {
        let original = MaterialID.allCases

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode([MaterialID].self, from: data)

        #expect(decoded == original)
    }
}
