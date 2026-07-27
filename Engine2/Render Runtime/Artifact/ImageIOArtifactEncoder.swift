import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Immutable Image I/O derivation of encoded artifacts from render results.
///
/// Artifact encoding is deliberately above the Render Runtime boundary. The
/// encoder neither samples application state nor touches Metal, and it never
/// rerenders. A caller can therefore retry encoding, or derive artifacts with
/// different policies, from the same immutable render result without
/// changing its exact Simulation and viewpoint attribution.
///
/// The source image is already top-left, BGRA8, and sRGB encoded. Its opaque
/// fourth byte is intentionally skipped for both currently supported formats
/// because the offscreen render contract guarantees opacity. No row flip or
/// second transfer-function application belongs in this layer.
///
/// The asynchronous protocol operation runs on the concurrent executor rather
/// than the caller's actor. Caller cancellation is checked by the workflow
/// before this operation; once encoding begins, the completed artifact or
/// typed failure wins.
nonisolated struct ImageIOArtifactEncoder: PImageArtifactEncoder {
    /// Required standard color space resolved once before any workflow can use
    /// this encoder.
    private let colorSpace: CGColorSpace

    /// Resolves the fixed Core Graphics resource required by every artifact.
    init() throws(ImageArtifactEncoderError) {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw .couldNotCreateSRGBColorSpace
        }

        self.colorSpace = colorSpace
    }

    /// Encodes a completed raw render while preserving all render provenance.
    ///
    /// A failure leaves the source result unchanged and has no runtime-side
    /// effect, so callers may retry this transform independently of rendering.
    @concurrent
    func encode(
        _ result: OffscreenRenderResult,
        as encoding: ImageArtifactEncoding
    ) async throws(ImageArtifactEncoderError) -> RenderedImageArtifact {
        guard let provider = CGDataProvider(data: result.image.bytes as CFData) else {
            throw .couldNotCreateDataProvider
        }

        // With 32-bit little-endian words, logical XRGB is stored as BGRX.
        // That matches the source BGRA byte order while deliberately ignoring
        // its guaranteed-opaque alpha byte.
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
            throw .couldNotCreateImage
        }

        let destinationType: UTType
        let destinationProperties: CFDictionary?
        switch encoding {
        case let .jpeg(quality):
            destinationType = .jpeg
            destinationProperties = [
                kCGImageDestinationLossyCompressionQuality: quality.value
            ] as CFDictionary
        case .png:
            destinationType = .png
            destinationProperties = nil
        }

        // Image I/O requires mutable CFData as its incremental byte sink.
        // NSMutableData is the Foundation storage that bridges directly to
        // CFMutableData here and then exposes a stable byte count for the one
        // final immutable copy; there is no Swift-native Image I/O destination.
        let destinationData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            destinationData as CFMutableData,
            destinationType.identifier as CFString,
            1,
            nil
        ) else {
            throw .couldNotCreateDestination
        }

        CGImageDestinationAddImage(destination, image, destinationProperties)
        guard CGImageDestinationFinalize(destination) else {
            throw .destinationFinalizationFailed
        }

        // Copy the local mutable destination into detached immutable storage.
        let encodedData = Data(
            bytes: destinationData.bytes,
            count: destinationData.length
        )
        return RenderedImageArtifact(
            encoding: encoding,
            encodedData: encodedData,
            sourceRequestID: result.requestID,
            sourceCursor: result.sourceCursor,
            viewpoint: result.viewpoint,
            renderSettings: result.settings
        )
    }
}
