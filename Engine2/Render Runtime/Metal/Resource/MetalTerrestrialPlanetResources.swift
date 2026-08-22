import Metal

/// Device-resolved generated maps for one terrestrial-planet appearance.
///
/// Render generates the detached pixels from Game Content's recipe, writes the
/// complete mip chains into immutable-after-construction textures, and retains
/// those allocations for its lifetime. Simulation and Game Content never own
/// decoded pixels or GPU resources.
struct MetalTerrestrialPlanetResources {
    let description: TerrestrialPlanetDescription
    let normalTexture: any MTLTexture
    let surfaceTexture: any MTLTexture
    let controlTexture: any MTLTexture
    let cloudTexture: any MTLTexture

    /// Complete texture allocation set required by every layered planet draw.
    var allocations: [any MTLAllocation] {
        [
            normalTexture,
            surfaceTexture,
            controlTexture,
            cloudTexture
        ]
    }

    /// Generates and resolves every immutable map before publishing the resource set.
    init(
        description: TerrestrialPlanetDescription,
        device: any MTLDevice
    ) throws(MetalResourceStoreError) {
        let maps = TerrestrialPlanetSurfaceGenerator().generate(
            description.surfaceRecipe
        )
        let textureBuilder = MetalTerrestrialPlanetTextureBuilder(
            device: device
        )
        let normalTexture = try textureBuilder.makeNormalTexture(
            pixels: maps.normalRGBA8,
            width: maps.width,
            height: maps.height
        )
        let surfaceTexture = try textureBuilder.makeSurfaceTexture(
            pixels: maps.surfaceRGBA8,
            width: maps.width,
            height: maps.height
        )
        let controlTexture = try textureBuilder.makeControlTexture(
            pixels: maps.controlRGBA8,
            width: maps.width,
            height: maps.height
        )
        let cloudTexture = try textureBuilder.makeCloudTexture(
            pixels: maps.cloudRGBA8,
            width: maps.width,
            height: maps.height
        )

        try Self.validate(
            normalTexture: normalTexture,
            surfaceTexture: surfaceTexture,
            controlTexture: controlTexture,
            cloudTexture: cloudTexture,
            expectedWidth: maps.width,
            expectedHeight: maps.height
        )

        self.description = description
        self.normalTexture = normalTexture
        self.surfaceTexture = surfaceTexture
        self.controlTexture = controlTexture
        self.cloudTexture = cloudTexture
    }

    /// Proves the generated maps share their shape, mip coverage, and shader formats.
    private static func validate(
        normalTexture: any MTLTexture,
        surfaceTexture: any MTLTexture,
        controlTexture: any MTLTexture,
        cloudTexture: any MTLTexture,
        expectedWidth: Int,
        expectedHeight: Int
    ) throws(MetalResourceStoreError) {
        let textures = [
            normalTexture,
            surfaceTexture,
            controlTexture,
            cloudTexture
        ]
        let expectedMipmapLevelCount = mipmapLevelCount(
            width: expectedWidth,
            height: expectedHeight
        )

        for texture in textures {
            guard texture.width == expectedWidth,
                  texture.height == expectedHeight
            else {
                throw .invalidTerrestrialPlanetTextureDimensions(
                    label: texture.label,
                    width: texture.width,
                    height: texture.height
                )
            }
            guard texture.mipmapLevelCount == expectedMipmapLevelCount else {
                throw .incompleteTerrestrialPlanetMipChain(
                    label: texture.label,
                    actualLevelCount: texture.mipmapLevelCount,
                    expectedLevelCount: expectedMipmapLevelCount
                )
            }
        }

        guard normalTexture.pixelFormat == .rgba8Unorm,
              surfaceTexture.pixelFormat == .rgba8Unorm_srgb,
              controlTexture.pixelFormat == .rgba8Unorm,
              cloudTexture.pixelFormat == .rgba8Unorm
        else {
            throw .invalidTerrestrialPlanetTextureFormats(
                normal: normalTexture.pixelFormat,
                surface: surfaceTexture.pixelFormat,
                control: controlTexture.pixelFormat,
                clouds: cloudTexture.pixelFormat
            )
        }
    }

    private static func mipmapLevelCount(width: Int, height: Int) -> Int {
        var largestDimension = max(width, height)
        var levelCount = 1
        while largestDimension > 1 {
            largestDimension /= 2
            levelCount += 1
        }
        return levelCount
    }
}
