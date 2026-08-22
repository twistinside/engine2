/// Detached base-level pixels for one generated terrestrial surface.
///
/// Every map uses equirectangular RGBA8 storage with identical dimensions.
/// Normal, control, and cloud channels are linear. Surface RGB contains sRGB
/// samples, while its alpha channel remains a linear binary land mask. Render
/// may derive backend-owned mip levels without exposing these bytes to Game
/// Content or Simulation.
nonisolated struct TerrestrialPlanetSurfaceMaps: Equatable, Sendable {
    /// Number of channels in every generated pixel.
    static let channelCount = 4

    let width: Int
    let height: Int

    /// East, south, and radial tangent-space normal mapped into `0...255`.
    /// Alpha is always `255`.
    let normalRGBA8: [UInt8]

    /// sRGB surface color plus a binary land mask in alpha.
    let surfaceRGBA8: [UInt8]

    /// Linear moisture, vegetation, ice, and perceptual roughness.
    let controlRGBA8: [UInt8]

    /// Linear cloud coverage, density, detail, and repeated coverage.
    let cloudRGBA8: [UInt8]

    init(
        width: Int,
        height: Int,
        normalRGBA8: [UInt8],
        surfaceRGBA8: [UInt8],
        controlRGBA8: [UInt8],
        cloudRGBA8: [UInt8]
    ) {
        precondition(
            width > 0 && height > 0,
            "Procedural planet maps require positive dimensions."
        )
        let (pixelCount, pixelCountOverflow) = width.multipliedReportingOverflow(
            by: height
        )
        let (expectedByteCount, byteCountOverflow) = pixelCount
            .multipliedReportingOverflow(by: Self.channelCount)
        precondition(
            !pixelCountOverflow && !byteCountOverflow,
            "Procedural planet map dimensions exceed addressable storage."
        )

        for bytes in [
            normalRGBA8,
            surfaceRGBA8,
            controlRGBA8,
            cloudRGBA8
        ] {
            precondition(
                bytes.count == expectedByteCount,
                "Every procedural planet map must contain one complete RGBA8 pixel grid."
            )
        }

        self.width = width
        self.height = height
        self.normalRGBA8 = normalRGBA8
        self.surfaceRGBA8 = surfaceRGBA8
        self.controlRGBA8 = controlRGBA8
        self.cloudRGBA8 = cloudRGBA8
    }
}
