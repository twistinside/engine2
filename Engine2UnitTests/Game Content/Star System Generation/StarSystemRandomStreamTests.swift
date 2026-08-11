import Testing
@testable import Engine2

nonisolated struct StarSystemRandomStreamTests {
    @Test func pinnedAddressedWordsDefineTheVersionOneStream() {
        var random = StarSystemRandomStream(
            seed: StarSystemSeed(rawValue: 0x1234),
            modelVersion: .coreAccretionLiteV1,
            domain: .star
        )

        #expect(random.nextUInt64() == 0x9EB3_57B5_85D2_0479)
        #expect(random.nextUInt64() == 0xADB3_5A9C_6DC8_3FA9)
        #expect(random.nextUInt64() == 0x1299_9364_D5A6_9B59)
        #expect(random.nextUInt64() == 0x0D1E_34BF_8C1B_C3F1)
    }

    @Test func sameAddressReproducesWithoutSharedState() {
        var first = StarSystemRandomStream(
            seed: StarSystemSeed(rawValue: 42),
            modelVersion: .coreAccretionLiteV1,
            domain: .moons,
            discriminator: 7
        )
        var second = StarSystemRandomStream(
            seed: StarSystemSeed(rawValue: 42),
            modelVersion: .coreAccretionLiteV1,
            domain: .moons,
            discriminator: 7
        )

        #expect((0..<16).map { _ in first.nextUInt64() } == (0..<16).map { _ in second.nextUInt64() })
    }

    @Test func domainsAndLocalIdentitiesAreIndependentAddresses() {
        var star = StarSystemRandomStream(
            seed: StarSystemSeed(rawValue: 42),
            modelVersion: .coreAccretionLiteV1,
            domain: .star
        )
        var disk = StarSystemRandomStream(
            seed: StarSystemSeed(rawValue: 42),
            modelVersion: .coreAccretionLiteV1,
            domain: .disk
        )
        var dynamicalClearing = StarSystemRandomStream(
            seed: StarSystemSeed(rawValue: 42),
            modelVersion: .coreAccretionLiteV1,
            domain: .dynamicalClearing
        )
        var firstMoon = StarSystemRandomStream(
            seed: StarSystemSeed(rawValue: 42),
            modelVersion: .coreAccretionLiteV1,
            domain: .moons,
            discriminator: 1
        )
        var secondMoon = StarSystemRandomStream(
            seed: StarSystemSeed(rawValue: 42),
            modelVersion: .coreAccretionLiteV1,
            domain: .moons,
            discriminator: 2
        )

        let domainWords = Set([
            star.nextUInt64(),
            disk.nextUInt64(),
            dynamicalClearing.nextUInt64()
        ])

        #expect(domainWords.count == 3)
        #expect(firstMoon.nextUInt64() != secondMoon.nextUInt64())
    }

    @Test func unitUniformNeverIncludesItsUpperBound() {
        var random = StarSystemRandomStream(
            seed: StarSystemSeed(rawValue: 9),
            modelVersion: .coreAccretionLiteV1,
            domain: .formation
        )

        for _ in 0..<1_000 {
            let value = random.uniformUnit()
            #expect(value >= 0)
            #expect(value < 1)
        }
    }
}
