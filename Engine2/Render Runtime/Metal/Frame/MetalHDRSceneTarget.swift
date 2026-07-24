import Metal

/// One frame slot's drawable-sized linear HDR scene allocation.
///
/// Each target owns a dedicated residency set so replacing a resized target
/// never mutates a set referenced by another in-flight frame. `FrameResources`
/// replaces this value only after its availability semaphore proves prior GPU
/// work for the slot has completed.
@MainActor
final class MetalHDRSceneTarget {
    let texture: any MTLTexture
    let residencySet: any MTLResidencySet

    var width: Int {
        texture.width
    }

    var height: Int {
        texture.height
    }

    init(device: any MTLDevice, width: Int, height: Int) throws {
        precondition(
            width > 0 && height > 0,
            "An HDR scene target requires positive pixel dimensions."
        )

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: MetalFrameEncoder.sceneColorPixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.storageMode = .private
        textureDescriptor.usage = [.renderTarget, .shaderRead]
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            throw MetalResourceStoreError.missingHDRSceneTarget
        }
        texture.label = "HDR Scene Color \(width)x\(height)"

        let residencyDescriptor = MTLResidencySetDescriptor()
        residencyDescriptor.label = "HDR Scene Color \(width)x\(height)"
        residencyDescriptor.initialCapacity = 1
        let residencySet = try device.makeResidencySet(
            descriptor: residencyDescriptor
        )
        residencySet.addAllocation(texture)
        residencySet.commit()

        self.texture = texture
        self.residencySet = residencySet
    }

    func matches(width: Int, height: Int) -> Bool {
        self.width == width && self.height == height
    }
}
