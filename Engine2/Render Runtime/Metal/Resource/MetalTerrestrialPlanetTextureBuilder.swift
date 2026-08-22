import Foundation
import Metal
import simd

/// Creates immutable sampled planet maps from detached procedural pixels.
///
/// The builder writes every mip level before returning a texture. The
/// resulting shared allocation needs no later CPU mutation or upload pass and
/// can enter the Render Runtime's static residency set immediately.
struct MetalTerrestrialPlanetTextureBuilder {
    private let device: any MTLDevice

    init(device: any MTLDevice) {
        self.device = device
    }

    /// Creates a linear tangent-space normal map with normalized mip levels.
    func makeNormalTexture(
        pixels: [UInt8],
        width: Int,
        height: Int
    ) throws(MetalResourceStoreError) -> any MTLTexture {
        try makeTexture(
            pixels: pixels,
            width: width,
            height: height,
            pixelFormat: .rgba8Unorm,
            label: "Procedural Terrestrial Planet Normals",
            nextMipLevel: downsampleNormals
        )
    }

    /// Creates an sRGB surface-color map with linear-light color mip levels.
    func makeSurfaceTexture(
        pixels: [UInt8],
        width: Int,
        height: Int
    ) throws(MetalResourceStoreError) -> any MTLTexture {
        try makeTexture(
            pixels: pixels,
            width: width,
            height: height,
            pixelFormat: .rgba8Unorm_srgb,
            label: "Procedural Terrestrial Planet Surface",
            nextMipLevel: downsampleSRGB
        )
    }

    /// Creates a linear control map with box-filtered mip levels.
    func makeControlTexture(
        pixels: [UInt8],
        width: Int,
        height: Int
    ) throws(MetalResourceStoreError) -> any MTLTexture {
        try makeTexture(
            pixels: pixels,
            width: width,
            height: height,
            pixelFormat: .rgba8Unorm,
            label: "Procedural Terrestrial Planet Control",
            nextMipLevel: downsampleLinear
        )
    }

    /// Creates a linear cloud map with box-filtered mip levels.
    func makeCloudTexture(
        pixels: [UInt8],
        width: Int,
        height: Int
    ) throws(MetalResourceStoreError) -> any MTLTexture {
        try makeTexture(
            pixels: pixels,
            width: width,
            height: height,
            pixelFormat: .rgba8Unorm,
            label: "Procedural Terrestrial Planet Clouds",
            nextMipLevel: downsampleLinear
        )
    }

    private func makeTexture(
        pixels: [UInt8],
        width: Int,
        height: Int,
        pixelFormat: MTLPixelFormat,
        label: String,
        nextMipLevel: ([UInt8], Int, Int) -> [UInt8]
    ) throws(MetalResourceStoreError) -> any MTLTexture {
        precondition(width > 0 && height > 0, "A procedural planet map must have positive dimensions.")
        precondition(
            pixels.count == width * height * 4,
            "A procedural planet map must contain one RGBA8 sample per texel."
        )

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: true
        )
        descriptor.storageMode = .shared
        descriptor.usage = .shaderRead

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw .couldNotCreateTerrestrialPlanetTexture(label: label)
        }
        texture.label = label

        var levelPixels = pixels
        var levelWidth = width
        var levelHeight = height
        for level in 0..<texture.mipmapLevelCount {
            levelPixels.withUnsafeBytes { bytes in
                texture.replace(
                    region: MTLRegionMake2D(0, 0, levelWidth, levelHeight),
                    mipmapLevel: level,
                    withBytes: bytes.baseAddress!,
                    bytesPerRow: levelWidth * 4
                )
            }

            guard level + 1 < texture.mipmapLevelCount else {
                continue
            }
            levelPixels = nextMipLevel(
                levelPixels,
                levelWidth,
                levelHeight
            )
            levelWidth = max(levelWidth / 2, 1)
            levelHeight = max(levelHeight / 2, 1)
        }

        return texture
    }

    private func downsampleLinear(
        _ source: [UInt8],
        width: Int,
        height: Int
    ) -> [UInt8] {
        let destinationWidth = max(width / 2, 1)
        let destinationHeight = max(height / 2, 1)
        var destination = [UInt8](
            repeating: 0,
            count: destinationWidth * destinationHeight * 4
        )

        for destinationY in 0..<destinationHeight {
            for destinationX in 0..<destinationWidth {
                let destinationOffset = (
                    destinationY * destinationWidth + destinationX
                ) * 4
                for channel in 0..<4 {
                    let sum = sourceChannelSum(
                        source,
                        width: width,
                        height: height,
                        destinationX: destinationX,
                        destinationY: destinationY,
                        channel: channel
                    )
                    destination[destinationOffset + channel] = UInt8(
                        (sum + 2) / 4
                    )
                }
            }
        }

        return destination
    }

    private func downsampleSRGB(
        _ source: [UInt8],
        width: Int,
        height: Int
    ) -> [UInt8] {
        let destinationWidth = max(width / 2, 1)
        let destinationHeight = max(height / 2, 1)
        var destination = [UInt8](
            repeating: 0,
            count: destinationWidth * destinationHeight * 4
        )

        for destinationY in 0..<destinationHeight {
            for destinationX in 0..<destinationWidth {
                let destinationOffset = (
                    destinationY * destinationWidth + destinationX
                ) * 4
                for channel in 0..<3 {
                    var linearSum = 0.0
                    for sourceY in 0..<2 {
                        for sourceX in 0..<2 {
                            let x = min(
                                destinationX * 2 + sourceX,
                                width - 1
                            )
                            let y = min(
                                destinationY * 2 + sourceY,
                                height - 1
                            )
                            linearSum += linearFromSRGB(
                                source[(y * width + x) * 4 + channel]
                            )
                        }
                    }
                    destination[destinationOffset + channel] = encodedSRGB(
                        linearSum / 4
                    )
                }
                let alphaSum = sourceChannelSum(
                    source,
                    width: width,
                    height: height,
                    destinationX: destinationX,
                    destinationY: destinationY,
                    channel: 3
                )
                destination[destinationOffset + 3] = UInt8(
                    (alphaSum + 2) / 4
                )
            }
        }

        return destination
    }

    private func downsampleNormals(
        _ source: [UInt8],
        width: Int,
        height: Int
    ) -> [UInt8] {
        let destinationWidth = max(width / 2, 1)
        let destinationHeight = max(height / 2, 1)
        var destination = [UInt8](
            repeating: 0,
            count: destinationWidth * destinationHeight * 4
        )

        for destinationY in 0..<destinationHeight {
            for destinationX in 0..<destinationWidth {
                var normalSum = SIMD3<Float>.zero
                for sourceY in 0..<2 {
                    for sourceX in 0..<2 {
                        let x = min(destinationX * 2 + sourceX, width - 1)
                        let y = min(destinationY * 2 + sourceY, height - 1)
                        let sourceOffset = (y * width + x) * 4
                        normalSum += SIMD3<Float>(
                            decodedNormalChannel(source[sourceOffset]),
                            decodedNormalChannel(source[sourceOffset + 1]),
                            decodedNormalChannel(source[sourceOffset + 2])
                        )
                    }
                }

                let normal = simd_length_squared(normalSum) > 1e-8
                    ? simd_normalize(normalSum)
                    : SIMD3<Float>(0, 0, 1)
                let destinationOffset = (
                    destinationY * destinationWidth + destinationX
                ) * 4
                destination[destinationOffset] = encodedNormalChannel(normal.x)
                destination[destinationOffset + 1] = encodedNormalChannel(normal.y)
                destination[destinationOffset + 2] = encodedNormalChannel(normal.z)
                destination[destinationOffset + 3] = 255
            }
        }

        return destination
    }

    private func sourceChannelSum(
        _ source: [UInt8],
        width: Int,
        height: Int,
        destinationX: Int,
        destinationY: Int,
        channel: Int
    ) -> Int {
        var sum = 0
        for sourceY in 0..<2 {
            for sourceX in 0..<2 {
                let x = min(destinationX * 2 + sourceX, width - 1)
                let y = min(destinationY * 2 + sourceY, height - 1)
                sum += Int(source[(y * width + x) * 4 + channel])
            }
        }
        return sum
    }

    private func linearFromSRGB(_ sample: UInt8) -> Double {
        let value = Double(sample) / 255
        return value <= 0.04045
            ? value / 12.92
            : pow((value + 0.055) / 1.055, 2.4)
    }

    private func encodedSRGB(_ linear: Double) -> UInt8 {
        let value = linear <= 0.0031308
            ? linear * 12.92
            : 1.055 * pow(linear, 1 / 2.4) - 0.055
        return UInt8((min(max(value, 0), 1) * 255).rounded())
    }

    private func decodedNormalChannel(_ sample: UInt8) -> Float {
        Float(sample) / 255 * 2 - 1
    }

    private func encodedNormalChannel(_ value: Float) -> UInt8 {
        UInt8(((min(max(value, -1), 1) * 0.5 + 0.5) * 255).rounded())
    }
}
