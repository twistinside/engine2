import Testing
@testable import Engine2

struct RenderAssetCatalogTests {
    @Test func completeMaterialVocabularyPassesCoverageValidation() throws {
        let catalog = RenderAssetCatalog(
            models: [:],
            materials: BasicGameContent().renderAssetCatalog.materials
        )

        try catalog.validateMaterialCoverage()
    }

    @Test func missingMaterialErrorUsesExhaustiveVocabularyOrder() {
        let catalog = RenderAssetCatalog(models: [:], materials: [:])

        do {
            try catalog.validateMaterialCoverage()
            Issue.record("Expected incomplete material content to be rejected.")
        } catch let error as RenderAssetCatalogError {
            // The error must follow the enum declaration rather than unstable
            // dictionary ordering so diagnostics remain reproducible.
            #expect(
                error == .missingMaterialDescriptions(MaterialID.allCases)
            )
        } catch {
            Issue.record("Unexpected material coverage error: \(error)")
        }
    }

    @Test func lookupReturnsAuthoredValueAndNeverFallsBack() throws {
        let catalog = RenderAssetCatalog(
            models: [:],
            materials: [.goldMetal: Self.goldMetal]
        )

        #expect(
            try catalog.materialDescription(for: .goldMetal) == Self.goldMetal
        )

        do {
            _ = try catalog.materialDescription(for: .warmDielectric)
            Issue.record("Expected a missing material lookup to throw.")
        } catch let error as RenderAssetCatalogError {
            #expect(
                error == .missingMaterialDescriptions([.warmDielectric])
            )
        } catch {
            Issue.record("Unexpected material lookup error: \(error)")
        }
    }

    private static let goldMetal = PBRMaterialDescription(
        baseColor: SIMD3<Float>(1, 0.766, 0.336),
        metallic: 1,
        perceptualRoughness: 0.35
    )
}
