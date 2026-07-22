import Dispatch
import Metal
import Testing
@testable import Engine2

struct MetalFrameEncoderTests {
    @MainActor
    @Test func encodesPublishedFrameIntoCallerOwnedOffscreenTargets() throws {
        let width = 320
        let height = 240
        let scene = PublishedMaterialValidationScene()
        let resources = try MetalResourceStore(
            renderAssetCatalog: scene.catalog,
            frameCount: 1
        )
        let encoder = try MetalFrameEncoder(resources: resources)

        // Content resolution is deliberately complete before acquiring the
        // mutable frame slot or resetting its allocator. A caller can therefore
        // reject malformed authored content without disturbing live GPU state.
        let prepared = try encoder.prepare(scene.renderFrame)
        #expect(prepared.renderFrame == scene.renderFrame)
        #expect(
            prepared.materialDescriptions.count == min(
                scene.renderFrame.instances.count,
                FrameResources.maximumInstanceCount
            )
        )
        #expect(
            prepared.renderFrame.sourceCursor == scene.renderFrame.sourceCursor
        )
        #expect(
            prepared.renderFrame.viewpointID == scene.renderFrame.viewpointID
        )
        #expect(
            prepared.renderFrame.viewpointRevision
                == scene.renderFrame.viewpointRevision
        )

        let frame = try #require(resources.frames.first)
        frame.waitUntilAvailable()
        var callerOwnsFrame = true
        defer {
            if callerOwnsFrame {
                frame.markAvailable()
            }
        }

        let destinationTexture = try makeTexture(
            device: resources.device,
            pixelFormat: MetalFrameEncoder.destinationColorPixelFormat,
            width: width,
            height: height,
            storageMode: .shared,
            usage: .renderTarget
        )
        let depthTexture = try makeTexture(
            device: resources.device,
            pixelFormat: MetalFrameEncoder.depthPixelFormat,
            width: width,
            height: height,
            storageMode: .private,
            usage: .renderTarget
        )
        let sceneTarget = try frame.prepareHDRSceneTarget(
            device: resources.device,
            width: width,
            height: height
        )
        let targetResidency = try makeResidencySet(
            device: resources.device,
            allocations: [
                depthTexture as any MTLAllocation,
                destinationTexture as any MTLAllocation
            ]
        )

        frame.commandAllocator.reset()
        let commandBuffer = try #require(resources.device.makeCommandBuffer())
        commandBuffer.beginCommandBuffer(allocator: frame.commandAllocator)
        commandBuffer.useResidencySet(sceneTarget.residencySet)
        commandBuffer.useResidencySet(targetResidency)

        try encoder.encode(
            prepared,
            frameResources: frame,
            sceneColorTexture: sceneTarget.texture,
            depthTexture: depthTexture,
            destinationTexture: destinationTexture,
            clearColor: MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1),
            outputMode: .surface,
            into: commandBuffer
        )
        commandBuffer.endCommandBuffer()

        // This is the production encoder driven entirely by caller-owned
        // textures and a Metal 4 command buffer. No MTKView or CAMetalDrawable
        // participates in target acquisition, encoding, or submission.
        let submission = MetalOffscreenTestSubmission(
            retaining: [
                resources as AnyObject,
                encoder as AnyObject,
                frame as AnyObject,
                sceneTarget as AnyObject,
                depthTexture as AnyObject,
                destinationTexture as AnyObject,
                targetResidency as AnyObject
            ]
        )
        let commitOptions = MTL4CommitOptions()
        commitOptions.addFeedbackHandler { feedback in
            frame.markAvailable()
            submission.complete(feedbackError: feedback.error)
        }
        resources.commandQueue.commit([commandBuffer], options: commitOptions)
        callerOwnsFrame = false

        try submission.waitForCompletion(timeout: .now() + 5)

        #expect(destinationTexture.width == width)
        #expect(destinationTexture.height == height)

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](
            repeating: 0,
            count: bytesPerRow * height
        )
        try pixels.withUnsafeMutableBytes { bytes in
            let baseAddress = try #require(bytes.baseAddress)
            destinationTexture.getBytes(
                baseAddress,
                bytesPerRow: bytesPerRow,
                from: MTLRegionMake2D(0, 0, width, height),
                mipmapLevel: 0
            )
        }

        let containsRenderedColor = stride(
            from: 0,
            to: pixels.count,
            by: bytesPerPixel
        ).contains { offset in
            pixels[offset] != 0
                || pixels[offset + 1] != 0
                || pixels[offset + 2] != 0
        }
        #expect(containsRenderedColor)
    }

    @MainActor
    private func makeTexture(
        device: any MTLDevice,
        pixelFormat: MTLPixelFormat,
        width: Int,
        height: Int,
        storageMode: MTLStorageMode,
        usage: MTLTextureUsage
    ) throws -> any MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.storageMode = storageMode
        descriptor.usage = usage
        return try #require(device.makeTexture(descriptor: descriptor))
    }

    @MainActor
    private func makeResidencySet(
        device: any MTLDevice,
        allocations: [any MTLAllocation]
    ) throws -> any MTLResidencySet {
        let descriptor = MTLResidencySetDescriptor()
        descriptor.label = "MetalFrameEncoder Offscreen Targets"
        descriptor.initialCapacity = allocations.count
        let residencySet = try device.makeResidencySet(
            descriptor: descriptor
        )
        for allocation in allocations {
            residencySet.addAllocation(allocation)
        }
        residencySet.commit()
        return residencySet
    }
}
