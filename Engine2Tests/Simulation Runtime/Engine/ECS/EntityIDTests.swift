//
//  EntityIDTests.swift
//  Engine2Tests
//
//  Created by Codex on 7/15/26.
//

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
}
