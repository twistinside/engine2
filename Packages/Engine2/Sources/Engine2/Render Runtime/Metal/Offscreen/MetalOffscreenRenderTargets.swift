import Foundation
import Metal

/// Owns the exact Metal allocations used by one offscreen render request.
///
/// The destination is shared BGRA8-sRGB storage so a completed submission can
/// be detached into a backend-neutral image without a blit pass. Depth remains
/// private, and one committed residency set groups both request-scoped targets
/// for explicit attachment to the submitted Metal 4 command buffer.
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

    /// Detaches tightly packed pixels after the owning workflow awaits feedback.
    func readback() throws -> RenderedBGRA8SRGBImage {
        var bytes = Data(count: size.bgra8ByteCount)
        try bytes.withUnsafeMutableBytes { storage in
            guard let baseAddress = storage.baseAddress else {
                throw MetalOffscreenRenderTargetError.missingReadbackStorage(
                    byteCount: size.bgra8ByteCount
                )
            }

            destinationTexture.getBytes(
                baseAddress,
                bytesPerRow: size.bgra8BytesPerRow,
                from: MTLRegionMake2D(0, 0, size.width, size.height),
                mipmapLevel: 0
            )
        }

        return try RenderedBGRA8SRGBImage(size: size, bytes: bytes)
    }
}
