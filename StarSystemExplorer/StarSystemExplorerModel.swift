import Observation

/// Owns seed editing and asynchronous projection of one immutable generated system into the explorer.
@Observable
final class StarSystemExplorerModel {
    var seedText: String
    private(set) var system: GeneratedStarSystem?
    private(set) var isGenerating = false
    private(set) var errorMessage: String?

    private let parser = StarSystemSeedParser()
    private let presentation = StarSystemPresentation()

    init(seedText: String = "1", system: GeneratedStarSystem? = nil) {
        self.seedText = seedText
        self.system = system
    }

    func generateIfNeeded() {
        guard system == nil, !isGenerating else {
            return
        }
        generate()
    }

    func generate() {
        guard !isGenerating else {
            return
        }
        guard let seed = parser.parse(seedText) else {
            errorMessage = "Enter a whole number from 0 through \(UInt64.max), or use a 0x hexadecimal value."
            return
        }

        isGenerating = true
        errorMessage = nil
        let generator = StarSystemGenerator(policy: .coreAccretionLiteV1)

        Task {
            let result = await Task.detached(priority: .userInitiated) {
                do {
                    return Result<GeneratedStarSystem, StarSystemGenerationError>.success(
                        try generator.generate(seed: seed)
                    )
                } catch let error as StarSystemGenerationError {
                    return Result<GeneratedStarSystem, StarSystemGenerationError>.failure(error)
                } catch {
                    return Result<GeneratedStarSystem, StarSystemGenerationError>.failure(.invalidPolicy)
                }
            }.value

            switch result {
            case .success(let generatedSystem):
                system = generatedSystem
            case .failure(let error):
                errorMessage = presentation.errorMessage(for: error)
            }
            isGenerating = false
        }
    }

    func chooseRandomSeed() {
        var generator = SystemRandomNumberGenerator()
        chooseRandomSeed(using: &generator)
    }

    func chooseRandomSeed(using generator: inout some RandomNumberGenerator) {
        guard !isGenerating else {
            return
        }
        seedText = String(generator.next())
        generate()
    }
}
