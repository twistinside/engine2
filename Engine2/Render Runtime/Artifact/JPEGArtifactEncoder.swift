import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Stateless CPU-side derivation of JPEG artifacts from completed render results.
///
/// Artifact encoding is deliberately above the Render Runtime boundary. The
/// encoder neither samples application state nor touches Metal, and it never
/// rerenders. A caller can therefore retry encoding, or derive artifacts with
/// different quality settings, from the same immutable render result without
/// changing its exact Simulation and viewpoint attribution.
///
/// The source image is already top-left, BGRA8, and sRGB encoded. Its opaque
/// fourth byte is intentionally skipped because JPEG cannot carry alpha and the
/// current offscreen render contract guarantees opacity. No row flip or second
/// transfer-function application belongs in this layer.
nonisolated struct JPEGArtifactEncoder: Sendable {
    /// Creates a stateless artifact encoder.
    init() {}

    /// Encodes a completed raw render while preserving all render provenance.
    ///
    /// A failure leaves the source result unchanged and has no runtime-side
    /// effect, so callers may retry this transform independently of rendering.
    func encode(
        _ result: OffscreenRenderResult,
        settings: JPEGEncodingSettings = JPEGEncodingSettings()
    ) throws -> RenderedImageArtifact {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw JPEGArtifactEncoderError.couldNotCreateSRGBColorSpace
        }
        guard let provider = CGDataProvider(data: result.image.bytes as CFData) else {
            throw JPEGArtifactEncoderError.couldNotCreateDataProvider
        }

        // With 32-bit little-endian words, logical XRGB is stored as BGRX.
        // That matches the source BGRA byte order while deliberately ignoring
        // its guaranteed-opaque alpha byte for JPEG's RGB-only destination.
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.union(
            CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue)
        )
        guard let image = CGImage(
            width: result.image.size.width,
            height: result.image.size.height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: result.image.bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else {
            throw JPEGArtifactEncoderError.couldNotCreateImage
        }

        let destinationData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            destinationData as CFMutableData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw JPEGArtifactEncoderError.couldNotCreateDestination
        }

        let properties = [
            kCGImageDestinationLossyCompressionQuality: settings.quality.value
        ] as CFDictionary
        CGImageDestinationAddImage(destination, image, properties)
        guard CGImageDestinationFinalize(destination) else {
            throw JPEGArtifactEncoderError.destinationFinalizationFailed
        }

        // Copy the local mutable destination into detached immutable storage.
        let encodedData = Data(
            bytes: destinationData.bytes,
            count: destinationData.length
        )
        return RenderedImageArtifact(
            format: .jpeg,
            encodedData: encodedData,
            sourceRequestID: result.requestID,
            sourceCursor: result.sourceCursor,
            viewpoint: result.viewpoint,
            renderSettings: result.settings,
            jpegSettings: settings
        )
    }
}
