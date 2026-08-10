import Foundation
import Testing
@testable import Engine2

struct RenderAssetCatalogTests {
    private static let goldMetal = PBRMaterialDescription(
        baseColor: SIMD3<Float>(1, 0.766, 0.336),
        metallic: 1,
        perceptualRoughness: 0.35
    )

    private static let terrestrialPlanet = TerrestrialPlanetDescription(
        elevationTextureID: .terrestrialPlanetElevation,
        surfaceTextureID: .terrestrialPlanetSurface,
        controlTextureID: .terrestrialPlanetControl,
        cloudTextureID: .terrestrialPlanetClouds,
        surfaceRadius: 1,
        maximumRelief: 0.035,
        seaLevel: 0.5,
        cloudRadius: 1.05,
        atmosphereRadius: 1.10,
        cloudOpacity: 0.82,
        atmosphereIntensity: 0.75,
        cloudShadowStrength: 0.65
    )

    private static let textureAssets = Dictionary(
        uniqueKeysWithValues: TextureID.allCases.map {
            (
                $0,
                TextureAssetReference(
                    resourceURL: URL(
                        fileURLWithPath: "/tmp/\($0).png"
                    ),
                    interpretation: .linear
                )
            )
        }
    )

    @Test func completeMaterialVocabularyPassesCoverageValidation() throws {
        let catalog = RenderAssetCatalog.everything

        try catalog.validateMaterialCoverage()
    }

    @Test func missingMaterialErrorUsesExhaustiveVocabularyOrder() {
        let catalog = RenderAssetCatalog(models: [:], materials: [:])

        do {
            try catalog.validateMaterialCoverage()
            Issue.record("Expected incomplete material content to be rejected.")
        } catch let error {
            // The error must follow the enum declaration rather than unstable
            // dictionary ordering so diagnostics remain reproducible.
            #expect(
                error == .missingMaterialDescriptions(MaterialID.allCases)
            )
        }
    }

    @Test func overlappingMaterialFamiliesAreRejectedBeforeLookup() {
        let catalog = RenderAssetCatalog(
            models: [:],
            materials: [.terrestrialPlanet: Self.goldMetal],
            terrestrialPlanets: [.terrestrialPlanet: Self.terrestrialPlanet],
            textures: Self.textureAssets
        )

        do {
            try catalog.validateMaterialCoverage()
            Issue.record("Expected overlapping material families to be rejected.")
        } catch let error {
            #expect(
                error == .overlappingMaterialDescriptions([.terrestrialPlanet])
            )
        }
    }

    @Test func missingReferencedTexturesUseExhaustiveVocabularyOrder() {
        var incompleteTextures = Self.textureAssets
        incompleteTextures[.terrestrialPlanetSurface] = nil
        incompleteTextures[.terrestrialPlanetClouds] = nil
        let catalog = RenderAssetCatalog(
            models: [:],
            materials: RenderAssetCatalog.everything.materials,
            terrestrialPlanets: [
                .terrestrialPlanet: Self.terrestrialPlanet
            ],
            textures: incompleteTextures
        )

        do {
            try catalog.validateMaterialCoverage()
            Issue.record("Expected missing texture assets to be rejected.")
        } catch let error {
            #expect(
                error == .missingTextureAssets([
                    .terrestrialPlanetSurface,
                    .terrestrialPlanetClouds
                ])
            )
        }
    }

    @Test func lookupReturnsEachAuthoredFamilyAndNeverFallsBack() throws {
        let catalog = RenderAssetCatalog(
            models: [:],
            materials: [.goldMetal: Self.goldMetal],
            terrestrialPlanets: [
                .terrestrialPlanet: Self.terrestrialPlanet
            ]
        )

        #expect(
            try catalog.materialDescription(for: .goldMetal) ==
                .opaquePBR(Self.goldMetal)
        )
        #expect(
            try catalog.materialDescription(for: .terrestrialPlanet) ==
                .terrestrialPlanet(Self.terrestrialPlanet)
        )

        do {
            _ = try catalog.materialDescription(for: .warmDielectric)
            Issue.record("Expected a missing material lookup to throw.")
        } catch let error {
            #expect(
                error == .missingMaterialDescriptions([.warmDielectric])
            )
        }
    }

    @Test func focusedPBRLookupDoesNotCoerceLayeredMaterials() throws {
        let catalog = RenderAssetCatalog(
            models: [:],
            materials: [.goldMetal: Self.goldMetal],
            terrestrialPlanets: [
                .terrestrialPlanet: Self.terrestrialPlanet
            ]
        )

        #expect(
            try catalog.pbrMaterialDescription(for: .goldMetal) ==
                Self.goldMetal
        )

        do {
            _ = try catalog.pbrMaterialDescription(for: .terrestrialPlanet)
            Issue.record("Expected a layered material to remain outside the PBR lookup.")
        } catch let error {
            #expect(
                error == .missingMaterialDescriptions([.terrestrialPlanet])
            )
        }
    }
}
