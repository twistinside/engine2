import Foundation
import Testing
@testable import Engine2

struct MaterialIDTests {
    @Test func allCasesPreservesTheExhaustiveContentVocabulary() {
        // Catalog preflight uses this exhaustive order when reporting missing
        // authored descriptions, so additions must be deliberate and tested.
        #expect(MaterialID.allCases == [.warmDielectric, .goldMetal])
    }

    @Test func codableRoundTripPreservesEveryGameContentIdentity() throws {
        let original = [
            MaterialID.warmDielectric,
            MaterialID.goldMetal
        ]

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode([MaterialID].self, from: data)

        #expect(decoded == original)
    }
}
