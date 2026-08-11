import Testing
@testable import Engine2

nonisolated struct StarSystemGeneratorTests {
    private let generator = StarSystemGenerator(policy: .coreAccretionLiteV1)

    @Test func sameSeedAndPolicyProduceExactEqualSystems() throws {
        let seed = StarSystemSeed(rawValue: 0xC0FFEE)

        let first = try generator.generate(seed: seed)
        let second = try generator.generate(seed: seed)

        #expect(first == second)
        try first.validate()
    }

    @Test func differentSeedsChangeResolvedPhysicalFacts() throws {
        let first = try generator.generate(seed: StarSystemSeed(rawValue: 1))
        let second = try generator.generate(seed: StarSystemSeed(rawValue: 2))

        #expect(first != second)
        #expect(first.star != second.star)
    }

    @Test func canonicalVersionOneSystemsHavePinnedFingerprints() throws {
        let expectedFingerprints: [UInt64: UInt64] = [
            1: 14_866_552_184_008_552_229,
            17: 9_718_631_471_162_595_641,
            0xC0FFEE: 16_367_645_660_489_072_955
        ]

        for (rawSeed, expectedFingerprint) in expectedFingerprints.sorted(by: { $0.key < $1.key }) {
            let system = try generator.generate(seed: StarSystemSeed(rawValue: rawSeed))
            let fixture = GeneratedStarSystemFixture(system: system)
            let actualFingerprint = try fixture.canonicalFingerprint()

            #expect(
                actualFingerprint == expectedFingerprint,
                "Seed \(rawSeed) produced fingerprint \(actualFingerprint)."
            )
        }
    }

    @Test func resultRetainsCompleteGenerationProvenance() throws {
        let seed = StarSystemSeed(rawValue: 17)

        let system = try generator.generate(seed: seed)

        #expect(system.seed == seed)
        #expect(system.modelVersion == .coreAccretionLiteV1)
        #expect(system.policy == .coreAccretionLiteV1)
        #expect(system.protoplanetaryDisk.annulusCount == 128)
        #expect(system.formationLedger.seededEmbryoCount > 0)
    }
}
