import Foundation
import Testing
@testable import Engine2

struct EntityIDTests {
    @Test func generationParticipatesInIdentityAndHashing() {
        let firstGeneration = EntityID(index: 5, generation: 0)
        let nextGeneration = EntityID(index: 5, generation: 1)
        let otherIndex = EntityID(index: 6, generation: 0)

        #expect(firstGeneration != nextGeneration)
        #expect(Set([firstGeneration, nextGeneration, otherIndex]).count == 3)
    }

    @Test func codableRoundTripPreservesIndexAndGeneration() throws {
        let original = EntityID(index: 17, generation: 4)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EntityID.self, from: data)

        #expect(decoded == original)
    }
}
