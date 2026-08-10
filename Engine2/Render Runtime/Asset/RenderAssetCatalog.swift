/// Render-owned input contract for backend-neutral Game Content descriptions.
///
/// Game Content populates this value with its exhaustive identities and
/// authored source descriptions. The Render Runtime validates and resolves
/// those values privately; decoded models and Metal resources never enter the
/// catalog.
nonisolated struct RenderAssetCatalog: Equatable, Sendable {
    /// Complete catalog for every asset declared by Basic Game Content.
    ///
    /// Callers may still construct a curated catalog with
    /// `init(models:materials:terrestrialPlanets:textures:)`.
    static let everything: Self = {
        // The dielectric row holds one scene-linear base color and metallic
        // factor constant so roughness is the only variable.
        let warmBaseColor = SIMD3<Float>(0.5, 0.25, 0.125)

        // The metal row follows the same controlled progression while
        // preserving the established M4 gold baseline at roughness 0.35.
        let goldBaseColor = SIMD3<Float>(1, 0.766, 0.336)

        return Self(
            models: [
                .ball: ModelAssetReference(
                    resourceURL: BasicGameContentResources.ballModelURL,
                    format: .usdz
                ),
                .terrestrialPlanet: ModelAssetReference(
                    resourceURL: BasicGameContentResources.terrestrialPlanetModelURL,
                    format: .usdz
                )
            ],
            materials: [
                .warmDielectricSmooth: PBRMaterialDescription(
                    baseColor: warmBaseColor,
                    metallic: 0,
                    perceptualRoughness: 0.2
                ),
                .warmDielectric: PBRMaterialDescription(
                    baseColor: warmBaseColor,
                    metallic: 0,
                    perceptualRoughness: 0.5
                ),
                .warmDielectricRough: PBRMaterialDescription(
                    baseColor: warmBaseColor,
                    metallic: 0,
                    perceptualRoughness: 0.8
                ),
                .goldMetalSmooth: PBRMaterialDescription(
                    baseColor: goldBaseColor,
                    metallic: 1,
                    perceptualRoughness: 0.2
                ),
                .goldMetal: PBRMaterialDescription(
                    baseColor: goldBaseColor,
                    metallic: 1,
                    perceptualRoughness: 0.35
                ),
                .goldMetalRough: PBRMaterialDescription(
                    baseColor: goldBaseColor,
                    metallic: 1,
                    perceptualRoughness: 0.8
                )
            ],
            terrestrialPlanets: [
                .terrestrialPlanet: TerrestrialPlanetDescription(
                    elevationTextureID: .terrestrialPlanetElevation,
                    surfaceTextureID: .terrestrialPlanetSurface,
                    controlTextureID: .terrestrialPlanetControl,
                    cloudTextureID: .terrestrialPlanetClouds,
                    surfaceRadius: 1,
                    maximumRelief: 0.006,
                    seaLevel: 0.5,
                    cloudRadius: 1.008,
                    atmosphereRadius: 1.018,
                    cloudOpacity: 0.82,
                    atmosphereIntensity: 0.32,
                    cloudShadowStrength: 0.16
                )
            ],
            textures: [
                .terrestrialPlanetElevation: TextureAssetReference(
                    resourceURL: BasicGameContentResources.terrestrialPlanetElevationTextureURL,
                    interpretation: .linear
                ),
                .terrestrialPlanetSurface: TextureAssetReference(
                    resourceURL: BasicGameContentResources.terrestrialPlanetSurfaceTextureURL,
                    interpretation: .sRGB
                ),
                .terrestrialPlanetControl: TextureAssetReference(
                    resourceURL: BasicGameContentResources.terrestrialPlanetControlTextureURL,
                    interpretation: .linear
                ),
                .terrestrialPlanetClouds: TextureAssetReference(
                    resourceURL: BasicGameContentResources.terrestrialPlanetCloudsTextureURL,
                    interpretation: .linear
                )
            ]
        )
    }()

    /// Packaged source assets keyed by Game Content mesh identity.
    let models: [MeshID: ModelAssetReference]

    /// Authored PBR factors keyed by Game Content material identity.
    let materials: [MaterialID: PBRMaterialDescription]

    /// Layered terrestrial-planet descriptions keyed by material identity.
    let terrestrialPlanets: [MaterialID: TerrestrialPlanetDescription]

    /// Packaged source textures keyed by Game Content texture identity.
    let textures: [TextureID: TextureAssetReference]

    /// Creates one catalog from caller-selected models and material families.
    ///
    /// Empty layered-material and texture dictionaries preserve focused PBR
    /// fixture construction. Call ``validateMaterialCoverage()`` before
    /// publishing a catalog as complete Game Content.
    init(
        models: [MeshID: ModelAssetReference],
        materials: [MaterialID: PBRMaterialDescription],
        terrestrialPlanets: [MaterialID: TerrestrialPlanetDescription] = [:],
        textures: [TextureID: TextureAssetReference] = [:]
    ) {
        self.models = models
        self.materials = materials
        self.terrestrialPlanets = terrestrialPlanets
        self.textures = textures
    }

    /// Verifies complete, exclusive material coverage and required textures.
    ///
    /// Dictionary iteration order is deliberately irrelevant. Missing values
    /// are collected in their Game Content enum order so errors remain stable
    /// across launches and platforms.
    func validateMaterialCoverage() throws(RenderAssetCatalogError) {
        let overlappingMaterialIDs = MaterialID.allCases.filter {
            materials[$0] != nil && terrestrialPlanets[$0] != nil
        }
        guard overlappingMaterialIDs.isEmpty else {
            throw RenderAssetCatalogError.overlappingMaterialDescriptions(
                overlappingMaterialIDs
            )
        }

        let missingMaterialIDs = MaterialID.allCases.filter {
            materials[$0] == nil && terrestrialPlanets[$0] == nil
        }
        guard missingMaterialIDs.isEmpty else {
            throw RenderAssetCatalogError.missingMaterialDescriptions(
                missingMaterialIDs
            )
        }

        let requiredTextureIDs = Set(
            terrestrialPlanets.values.flatMap(\.requiredTextureIDs)
        )
        let missingTextureIDs = TextureID.allCases.filter {
            requiredTextureIDs.contains($0) && textures[$0] == nil
        }
        guard missingTextureIDs.isEmpty else {
            throw RenderAssetCatalogError.missingTextureAssets(
                missingTextureIDs
            )
        }
    }

    /// Resolves one authored material family without a renderer fallback.
    ///
    /// Callers that accept a partial or otherwise unvalidated catalog receive a
    /// concrete content error before encoding a draw for the missing identity.
    func materialDescription(for id: MaterialID) throws(RenderAssetCatalogError) -> RenderMaterialDescription {
        let pbrDescription = materials[id]
        let terrestrialPlanetDescription = terrestrialPlanets[id]

        switch (pbrDescription, terrestrialPlanetDescription) {
        case let (.some(description), .none):
            return .opaquePBR(description)

        case let (.none, .some(description)):
            return .terrestrialPlanet(description)

        case (.some, .some):
            throw RenderAssetCatalogError.overlappingMaterialDescriptions([id])

        case (.none, .none):
            throw RenderAssetCatalogError.missingMaterialDescriptions([id])
        }
    }

    /// Resolves one ordinary opaque PBR description for focused legacy paths.
    ///
    /// Layered materials are not coerced into approximate PBR factors. Callers
    /// that support every material family should use ``materialDescription(for:)``.
    func pbrMaterialDescription(for id: MaterialID) throws(RenderAssetCatalogError) -> PBRMaterialDescription {
        guard let description = materials[id] else {
            throw RenderAssetCatalogError.missingMaterialDescriptions([id])
        }

        return description
    }
}
