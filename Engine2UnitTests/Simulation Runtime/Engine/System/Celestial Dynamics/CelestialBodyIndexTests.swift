import Testing
@testable import Engine2

struct CelestialBodyIndexTests {
    @Test func registrationBuildsBijectiveLookupInStableBodyOrder() throws {
        var index = CelestialBodyIndex()
        let outerBodyID = CelestialBodyID(rawValue: 9)
        let innerBodyID = CelestialBodyID(rawValue: 2)
        let outerEntityID = EntityID(index: 0, generation: 0)
        let innerEntityID = EntityID(index: 1, generation: 0)
        let starEntityID = EntityID(index: 2, generation: 0)

        try index.register(outerBodyID, for: outerEntityID)
        try index.register(.primaryStar, for: starEntityID)
        try index.register(innerBodyID, for: innerEntityID)

        #expect(index.orderedBodyIDs == [.primaryStar, innerBodyID, outerBodyID])
        #expect(index[outerBodyID] == outerEntityID)
        #expect(index[innerBodyID] == innerEntityID)
        #expect(index[.primaryStar] == starEntityID)
        #expect(index.bodyID(for: outerEntityID) == outerBodyID)
        #expect(index.bodyID(for: innerEntityID) == innerBodyID)
        #expect(index.bodyID(for: starEntityID) == .primaryStar)
        #expect(index.count == 3)
        #expect(!index.isEmpty)
    }

    @Test func registrationRejectsDuplicateIdentityInEitherDirection() throws {
        var index = CelestialBodyIndex()
        let bodyID = CelestialBodyID(rawValue: 4)
        let otherBodyID = CelestialBodyID(rawValue: 5)
        let entityID = EntityID(index: 8, generation: 1)
        let otherEntityID = EntityID(index: 9, generation: 1)
        try index.register(bodyID, for: entityID)

        #expect(
            throws: CelestialBodyIndex.RegistrationError.bodyIDAlreadyRegistered(
                bodyID: bodyID,
                entityID: entityID
            )
        ) {
            try index.register(bodyID, for: otherEntityID)
        }
        #expect(
            throws: CelestialBodyIndex.RegistrationError.entityIDAlreadyRegistered(
                entityID: entityID,
                bodyID: bodyID
            )
        ) {
            try index.register(otherBodyID, for: entityID)
        }

        #expect(index.orderedBodyIDs == [bodyID])
        #expect(index[bodyID] == entityID)
        #expect(index[otherBodyID] == nil)
    }
}
