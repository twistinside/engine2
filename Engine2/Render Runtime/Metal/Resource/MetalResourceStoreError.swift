import Metal

/// Failures that can prevent construction or use of a Metal resource store.
nonisolated enum MetalResourceStoreError: Error, Equatable {
    case missingDevice
    case missingCommandQueue
    case invalidFrameCount(Int)
    case missingDefaultShaderLibrary
    case missingOpaqueDepthStencilState
    case missingTranslucentDepthStencilState
    case missingTerrestrialPlanetSamplerState
    case couldNotCreateTerrestrialPlanetTexture(label: String)
    case invalidTerrestrialPlanetTextureDimensions(
        label: String?,
        width: Int,
        height: Int
    )
    case incompleteTerrestrialPlanetMipChain(
        label: String?,
        actualLevelCount: Int,
        expectedLevelCount: Int
    )
    case invalidTerrestrialPlanetTextureFormats(
        normal: MTLPixelFormat,
        surface: MTLPixelFormat,
        control: MTLPixelFormat,
        clouds: MTLPixelFormat
    )
    case missingFrameResource
    case missingHDRSceneTarget
}
