import Testing
@testable import Engine2
@testable import BasicGameContent

struct RenderAssetCatalogTests {
    private static let firstMaterialKey = MaterialAssetKey(rawValue: 7)
    private static let secondMaterialKey = MaterialAssetKey(rawValue: 11)
    private static let goldMetal = PBRMaterialDescription(
        baseColor: SIMD3<Float>(1, 0.766, 0.336),
        metallic: 1,
        perceptualRoughness: 0.35
    )

    @Test func completeMaterialVocabularyPassesCoverageValidation() throws {
        let basicCatalog = BasicGameContent().renderAssetCatalog
        let catalog = RenderAssetCatalog(
            models: [:],
            materials: basicCatalog.materials,
            requiredMaterialKeys: basicCatalog.requiredMaterialKeys
        )

        try catalog.validateMaterialCoverage()
    }

    @Test func missingMaterialErrorUsesExhaustiveVocabularyOrder() {
        let requiredMaterialKeys = MaterialID.allCases.map(\.assetKey)
        let catalog = RenderAssetCatalog(
            models: [:],
            materials: [:],
            requiredMaterialKeys: requiredMaterialKeys
        )

        do {
            try catalog.validateMaterialCoverage()
            Issue.record("Expected incomplete material content to be rejected.")
        } catch let error {
            // The error must follow the enum declaration rather than unstable
            // dictionary ordering so diagnostics remain reproducible.
            #expect(
                error == .missingMaterialDescriptions(requiredMaterialKeys)
            )
        }
    }

    @Test func lookupReturnsAuthoredValueAndNeverFallsBack() throws {
        let catalog = RenderAssetCatalog(
            models: [:],
            materials: [Self.firstMaterialKey: Self.goldMetal],
            requiredMaterialKeys: [
                Self.firstMaterialKey,
                Self.secondMaterialKey
            ]
        )

        #expect(
            try catalog.materialDescription(for: Self.firstMaterialKey) ==
                Self.goldMetal
        )

        do {
            _ = try catalog.materialDescription(for: Self.secondMaterialKey)
            Issue.record("Expected a missing material lookup to throw.")
        } catch let error {
            #expect(
                error == .missingMaterialDescriptions(
                    [Self.secondMaterialKey]
                )
            )
        }
    }
}
