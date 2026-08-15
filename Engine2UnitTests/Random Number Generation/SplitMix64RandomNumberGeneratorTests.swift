import Testing
@testable import Engine2

nonisolated struct SplitMix64RandomNumberGeneratorTests {
    @Test func seedWhiteningAndAdvancementHavePinnedWords() {
        var zeroSeed = SplitMix64RandomNumberGenerator(seed: 0)
        var nonzeroSeed = SplitMix64RandomNumberGenerator(seed: 1)

        #expect(zeroSeed.next() == 0xE220_A839_7B1D_CDAF)
        #expect(zeroSeed.next() == 0x6E78_9E6A_A1B9_65F4)
        #expect(zeroSeed.next() == 0x06C4_5D18_8009_454F)
        #expect(zeroSeed.next() == 0xF88B_B8A8_724C_81EC)
        #expect(nonzeroSeed.next() == 0xBFEF_8030_DDC2_D772)
    }

    @Test func equalSeedsProduceIndependentEqualStreams() {
        var first = SplitMix64RandomNumberGenerator(seed: 42)
        var second = SplitMix64RandomNumberGenerator(seed: 42)

        #expect((0..<16).map { _ in first.next() } == (0..<16).map { _ in second.next() })
    }
}
