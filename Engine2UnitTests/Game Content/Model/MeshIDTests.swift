import Foundation
import Testing
@testable import Engine2

struct MeshIDTests {
    @Test func codableRoundTripPreservesGameContentIdentity() throws {
        let original = MeshID.ball

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MeshID.self, from: data)

        #expect(decoded == original)
    }
}
