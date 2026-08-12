import Testing

@testable import StarSystemExplorer

@MainActor
struct StarSystemExplorerModelTests {
    @Test func randomSeedUsesTheSuppliedGeneratorAndStartsGeneration() async {
        var expectedGenerator = SplitMix64RandomNumberGenerator(seed: 7)
        let expectedSeed = expectedGenerator.next()
        var generator = SplitMix64RandomNumberGenerator(seed: 7)
        let model = StarSystemExplorerModel(seedText: "1")

        model.chooseRandomSeed(using: &generator)

        #expect(model.seedText == String(expectedSeed))
        while model.isGenerating {
            await Task.yield()
        }
        #expect(model.system?.seed.rawValue == expectedSeed)
    }
}
