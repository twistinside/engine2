import Metal

/// Persistent private attachments shared by one reusable benchmark frame slot.
///
/// The benchmark never reads the destination on the CPU. Both attachments
/// therefore use private storage and one committed residency set that is
/// attached to each command buffer using this slot.
final class RenderBenchmarkTargets {
    let size: RenderPixelSize
    let destinationTexture: any MTLTexture
    let depthTexture: any MTLTexture
    let residencySet: any MTLResidencySet

    init(device: any MTLDevice, size: RenderPixelSize) throws(RenderBenchmarkError) {
        let destinationDescriptor = MTLTextureDescriptor
            .texture2DDescriptor(
                pixelFormat: MetalFrameEncoder.destinationColorPixelFormat,
                width: size.width,
                height: size.height,
                mipmapped: false
            )
        destinationDescriptor.storageMode = .private
        destinationDescriptor.usage = .renderTarget
        guard let destinationTexture = device.makeTexture(
            descriptor: destinationDescriptor
        ) else {
            throw .missingDestinationTexture(size)
        }
        destinationTexture.label = "Benchmark Destination \(size.width)x\(size.height)"

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
            throw .missingDepthTexture(size)
        }
        depthTexture.label = "Benchmark Depth \(size.width)x\(size.height)"

        let residencyDescriptor = MTLResidencySetDescriptor()
        residencyDescriptor.label = "Benchmark Targets \(size.width)x\(size.height)"
        residencyDescriptor.initialCapacity = 2
        let residencySet: any MTLResidencySet
        do {
            residencySet = try device.makeResidencySet(
                descriptor: residencyDescriptor
            )
        } catch {
            throw .resourceConstructionFailed(String(describing: error))
        }
        residencySet.addAllocation(destinationTexture)
        residencySet.addAllocation(depthTexture)
        residencySet.commit()

        self.size = size
        self.destinationTexture = destinationTexture
        self.depthTexture = depthTexture
        self.residencySet = residencySet
    }
}
