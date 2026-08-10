import Metal

/// Device-resolved maps for one authored terrestrial-planet appearance.
///
/// The Render Runtime retains these immutable textures and makes them resident
/// for its lifetime. Simulation and Game Content continue to carry only typed
/// identities and backend-neutral source descriptions.
struct MetalTerrestrialPlanetResources {
    let description: TerrestrialPlanetDescription
    let elevationTexture: any MTLTexture
    let surfaceTexture: any MTLTexture
    let controlTexture: any MTLTexture
    let cloudTexture: any MTLTexture

    /// Resolves the description's exact map identities from an already loaded table.
    init(
        description: TerrestrialPlanetDescription,
        textures: [TextureID: any MTLTexture]
    ) throws {
        guard let elevationTexture = textures[
            description.elevationTextureID
        ] else {
            throw MetalResourceStoreError.missingTextureResource(
                description.elevationTextureID
            )
        }
        guard let surfaceTexture = textures[
            description.surfaceTextureID
        ] else {
            throw MetalResourceStoreError.missingTextureResource(
                description.surfaceTextureID
            )
        }
        guard let controlTexture = textures[
            description.controlTextureID
        ] else {
            throw MetalResourceStoreError.missingTextureResource(
                description.controlTextureID
            )
        }
        guard let cloudTexture = textures[
            description.cloudTextureID
        ] else {
            throw MetalResourceStoreError.missingTextureResource(
                description.cloudTextureID
            )
        }

        try Self.validate(
            elevationTexture: elevationTexture,
            surfaceTexture: surfaceTexture,
            controlTexture: controlTexture,
            cloudTexture: cloudTexture
        )

        self.description = description
        self.elevationTexture = elevationTexture
        self.surfaceTexture = surfaceTexture
        self.controlTexture = controlTexture
        self.cloudTexture = cloudTexture
    }

    /// Proves the fixed proof maps share their authored shape and GPU formats.
    private static func validate(
        elevationTexture: any MTLTexture,
        surfaceTexture: any MTLTexture,
        controlTexture: any MTLTexture,
        cloudTexture: any MTLTexture
    ) throws {
        let textures = [
            elevationTexture,
            surfaceTexture,
            controlTexture,
            cloudTexture
        ]
        let expectedWidth = 1_024
        let expectedHeight = 512
        let expectedMipmapLevelCount = 11

        for texture in textures {
            guard texture.width == expectedWidth,
                  texture.height == expectedHeight
            else {
                throw MetalResourceStoreError
                    .invalidTerrestrialPlanetTextureDimensions(
                        label: texture.label,
                        width: texture.width,
                        height: texture.height
                    )
            }
            guard texture.mipmapLevelCount == expectedMipmapLevelCount else {
                throw MetalResourceStoreError
                    .incompleteTerrestrialPlanetMipChain(
                        label: texture.label,
                        actualLevelCount: texture.mipmapLevelCount,
                        expectedLevelCount: expectedMipmapLevelCount
                    )
            }
        }

        guard elevationTexture.pixelFormat == .r16Unorm,
              isColorTextureFormat(surfaceTexture.pixelFormat),
              isLinearTextureFormat(controlTexture.pixelFormat),
              isLinearTextureFormat(cloudTexture.pixelFormat)
        else {
            throw MetalResourceStoreError.invalidTerrestrialPlanetTextureFormats(
                elevation: elevationTexture.pixelFormat,
                surface: surfaceTexture.pixelFormat,
                control: controlTexture.pixelFormat,
                clouds: cloudTexture.pixelFormat
            )
        }
    }

    /// Accepts either native four-channel byte order while preserving sRGB decoding.
    private static func isColorTextureFormat(
        _ pixelFormat: MTLPixelFormat
    ) -> Bool {
        pixelFormat == .rgba8Unorm_srgb || pixelFormat == .bgra8Unorm_srgb
    }

    /// Accepts either native four-channel byte order without transfer conversion.
    private static func isLinearTextureFormat(
        _ pixelFormat: MTLPixelFormat
    ) -> Bool {
        pixelFormat == .rgba8Unorm || pixelFormat == .bgra8Unorm
    }
}
