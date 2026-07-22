import Foundation
import Metal

/// Owns the exact Metal allocations used by one offscreen render request.
///
/// The destination is shared BGRA8-sRGB storage so a completed submission can
/// be detached into a backend-neutral image without a blit pass. Depth remains
/// private, and one committed residency set groups both request-scoped targets
/// for explicit attachment to the submitted Metal 4 command buffer.
@MainActor
final class MetalOffscreenRenderTargets {
    let size: RenderPixelSize
    let destinationTexture: any MTLTexture
    let depthTexture: any MTLTexture
    let residencySet: any MTLResidencySet

    /// Allocates matching destination and depth targets for one exact request.
    init(device: any MTLDevice, size: RenderPixelSize) throws {
        let destinationDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: MetalFrameEncoder.destinationColorPixelFormat,
            width: size.width,
            height: size.height,
            mipmapped: false
        )
        destinationDescriptor.storageMode = .shared
        destinationDescriptor.usage = .renderTarget
        guard let destinationTexture = device.makeTexture(
            descriptor: destinationDescriptor
        ) else {
            throw MetalOffscreenRenderTargetError.missingDestinationTexture(size)
        }
        destinationTexture.label = "Offscreen BGRA8-sRGB \(size.width)x\(size.height)"

        let depthDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: MetalFrameEncoder.depthPixelFormat,
            width: size.width,
            height: size.height,
            mipmapped: false
        )
        depthDescriptor.storageMode = .private
        depthDescriptor.usage = .renderTarget
        guard let depthTexture = device.makeTexture(
            descriptor: depthDescriptor
        ) else {
            throw MetalOffscreenRenderTargetError.missingDepthTexture(size)
        }
        depthTexture.label = "Offscreen Depth \(size.width)x\(size.height)"

        let residencyDescriptor = MTLResidencySetDescriptor()
        residencyDescriptor.label = "Offscreen Targets \(size.width)x\(size.height)"
        residencyDescriptor.initialCapacity = 2
        let residencySet = try device.makeResidencySet(
            descriptor: residencyDescriptor
        )
        residencySet.addAllocation(destinationTexture)
        residencySet.addAllocation(depthTexture)
        residencySet.commit()

        self.size = size
        self.destinationTexture = destinationTexture
        self.depthTexture = depthTexture
        self.residencySet = residencySet
    }

    /// Detaches tightly packed pixels only after successful queue feedback.
    ///
    /// Requiring the completion value at this boundary prevents callers from
    /// reading shared storage while the GPU can still be writing it.
    func readback(
        after completion: MetalOffscreenCompletion
    ) throws -> RenderedBGRA8SRGBImage {
        guard completion == .success else {
            throw MetalOffscreenRenderTargetError
                .readbackRequiresSuccessfulCompletion
        }

        let (bytesPerRow, rowOverflowed) = size.width
            .multipliedReportingOverflow(by: 4)
        guard !rowOverflowed else {
            throw RenderedBGRA8SRGBImageError.bytesPerRowOverflow(
                width: size.width
            )
        }

        let (byteCount, totalOverflowed) = bytesPerRow
            .multipliedReportingOverflow(by: size.height)
        guard !totalOverflowed else {
            throw RenderedBGRA8SRGBImageError.byteCountOverflow(
                bytesPerRow: bytesPerRow,
                height: size.height
            )
        }
        var bytes = Data(count: byteCount)
        try bytes.withUnsafeMutableBytes { storage in
            guard let baseAddress = storage.baseAddress else {
                throw MetalOffscreenRenderTargetError.missingReadbackStorage(
                    byteCount: byteCount
                )
            }

            destinationTexture.getBytes(
                baseAddress,
                bytesPerRow: bytesPerRow,
                from: MTLRegionMake2D(0, 0, size.width, size.height),
                mipmapLevel: 0
            )
        }

        return try RenderedBGRA8SRGBImage(size: size, bytes: bytes)
    }
}
