import Foundation
import Testing
@testable import Engine2

struct MeshIDTests {
    @Test func allCasesPreservesTheExhaustiveContentVocabulary() {
        #expect(MeshID.allCases == [.ball])
    }

    @Test func codableRoundTripPreservesEveryGameContentIdentity() throws {
        let original = MeshID.allCases

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode([MeshID].self, from: data)

        #expect(decoded == original)
    }
}
