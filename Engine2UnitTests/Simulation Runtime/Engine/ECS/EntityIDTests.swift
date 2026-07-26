import Testing
@testable import Engine2

struct EntityIDTests {
    @Test func generationParticipatesInIdentityAndHashing() {
        let firstGeneration = EntityID(index: 5, generation: 0)
        let nextGeneration = EntityID(index: 5, generation: 1)
        let otherIndex = EntityID(index: 6, generation: 0)
        let identities = Set([firstGeneration, nextGeneration, otherIndex])

        #expect(firstGeneration != nextGeneration)
        #expect(identities.count == 3)
    }
}
