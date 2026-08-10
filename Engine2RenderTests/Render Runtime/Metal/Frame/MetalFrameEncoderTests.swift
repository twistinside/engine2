import CoreGraphics
import Dispatch
import Metal
import Testing
@testable import Engine2

struct MetalFrameEncoderTests {
    @Test func encodesPublishedFrameIntoCallerOwnedOffscreenTargets() throws {
        let width = 320
        let height = 240
        let scene = PublishedMaterialValidationScene()
        let resources = try MetalResourceStore(
            renderAssetCatalog: scene.catalog,
            frameCount: 1
        )
        let encoder = MetalFrameEncoder(resources: resources)

        // Content resolution is deliberately complete before acquiring the
        // mutable frame slot or resetting its allocator. A caller can therefore
        // reject malformed authored content without disturbing live GPU state.
        let prepared = encoder.prepare(scene.renderFrame)
        #expect(prepared.renderFrame == scene.renderFrame)
        #expect(
            prepared.instances.count == min(
                scene.renderFrame.instances.count,
                FrameResources.maximumInstanceCount
            )
        )
        #expect(prepared.instances.allSatisfy { $0.model != nil })
        #expect(
            prepared.instances.map { $0.renderInstance.materialID }
                == scene.materialIDs
        )
        for instance in prepared.instances {
            let preparedModel = try #require(instance.model)
            let storedModel = try #require(resources.model(for: instance.renderInstance.meshID))
            #expect(preparedModel.meshes.map(ObjectIdentifier.init) == storedModel.meshes.map(ObjectIdentifier.init))
        }
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

        let inputs = try MetalFrameEncodingInputs(
            frameResources: frame,
            sceneColorTexture: sceneTarget.texture,
            depthTexture: depthTexture,
            destinationTexture: destinationTexture,
            clearColor: MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1),
            outputMode: .surface,
            exposure: .validation
        )
        #expect(inputs.drawableSize == CGSize(width: width, height: height))

        try encoder.encode(prepared, inputs: inputs, into: commandBuffer)
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

    @Test func preparationBoundsZeroOrdinaryMaximumAndExcessiveFrames() throws {
        let resources = try MetalResourceStore(
            renderAssetCatalog: .materialOnlyTestCatalog,
            frameCount: 1
        )
        let encoder = MetalFrameEncoder(resources: resources)

        for requestedCount in [
            0,
            1,
            FrameResources.maximumInstanceCount,
            FrameResources.maximumInstanceCount + 10
        ] {
            let prepared = encoder.prepare(
                makeRenderFrame(instanceCount: requestedCount)
            )
            let expectedCount = min(
                requestedCount,
                FrameResources.maximumInstanceCount
            )

            #expect(prepared.instances.count == expectedCount)
            #expect(prepared.terrestrialPlanetInstances.isEmpty)
            #expect(prepared.instanceCount == expectedCount)
            #expect(
                prepared.instances.allSatisfy {
                    $0.renderInstance.materialID == .warmDielectric
                        && resources.renderMaterialDescription(
                            for: .warmDielectric
                        ) == .opaquePBR($0.materialDescription)
                        && $0.model == nil
                }
            )
        }
    }

    @Test func preparationClassifiesOnePublishedPlanetWithoutCreatingOrdinaryDraws() throws {
        let content = BasicGameContent()
        let snapshot = content.worldBuilder.buildWorld().presentationSnapshot(
            at: SimulationCursor(
                sessionID: SimulationSessionID(),
                tick: SimulationTick(rawValue: 17)
            )
        )
        let renderFrame = RenderFrame(projecting: snapshot)
        let resources = try MetalResourceStore(
            renderAssetCatalog: content.renderAssetCatalog,
            frameCount: 1
        )
        let prepared = MetalFrameEncoder(resources: resources).prepare(
            renderFrame
        )

        #expect(renderFrame.instances.count == 1)
        #expect(prepared.renderFrame == renderFrame)
        #expect(prepared.instanceCount == 1)
        #expect(prepared.instances.isEmpty)
        #expect(prepared.terrestrialPlanetInstances.count == 1)

        let planet = try #require(prepared.terrestrialPlanetInstances.first)
        let expectedDescription = try #require(
            content.renderAssetCatalog.terrestrialPlanets[.terrestrialPlanet]
        )
        #expect(planet.renderInstance.meshID == .ball)
        #expect(planet.renderInstance.materialID == .terrestrialPlanet)
        #expect(planet.description == expectedDescription)
        #expect(planet.resources.description == expectedDescription)

        let preparedModel = try #require(planet.model)
        let storedModel = try #require(resources.model(for: .ball))
        #expect(
            preparedModel.meshes.map(ObjectIdentifier.init) ==
                storedModel.meshes.map(ObjectIdentifier.init)
        )
    }

    @Test func encodingInputsRejectMismatchedTargetDimensions() throws {
        let resources = try MetalResourceStore(
            renderAssetCatalog: .materialOnlyTestCatalog,
            frameCount: 1
        )
        let frame = try #require(resources.frames.first)
        let sceneColor = try makeTexture(
            device: resources.device,
            pixelFormat: MetalFrameEncoder.sceneColorPixelFormat,
            width: 16,
            height: 16,
            storageMode: .private,
            usage: .renderTarget
        )
        let depth = try makeTexture(
            device: resources.device,
            pixelFormat: MetalFrameEncoder.depthPixelFormat,
            width: 16,
            height: 15,
            storageMode: .private,
            usage: .renderTarget
        )
        let destination = try makeTexture(
            device: resources.device,
            pixelFormat: MetalFrameEncoder.destinationColorPixelFormat,
            width: 16,
            height: 16,
            storageMode: .shared,
            usage: .renderTarget
        )

        #expect(throws: MetalFrameEncoderError.mismatchedTargetDimensions) {
            try MetalFrameEncodingInputs(
                frameResources: frame,
                sceneColorTexture: sceneColor,
                depthTexture: depth,
                destinationTexture: destination,
                clearColor: MTLClearColor(
                    red: 0,
                    green: 0,
                    blue: 0,
                    alpha: 1
                ),
                outputMode: .surface,
                exposure: .validation
            )
        }
    }

    @Test func encodingInputsRejectUnexpectedTargetFormats() throws {
        let resources = try MetalResourceStore(
            renderAssetCatalog: .materialOnlyTestCatalog,
            frameCount: 1
        )
        let frame = try #require(resources.frames.first)
        let wrongSceneFormat = MetalFrameEncoder.destinationColorPixelFormat
        let sceneColor = try makeTexture(
            device: resources.device,
            pixelFormat: wrongSceneFormat,
            width: 16,
            height: 16,
            storageMode: .shared,
            usage: .renderTarget
        )
        let depth = try makeTexture(
            device: resources.device,
            pixelFormat: MetalFrameEncoder.depthPixelFormat,
            width: 16,
            height: 16,
            storageMode: .private,
            usage: .renderTarget
        )
        let destination = try makeTexture(
            device: resources.device,
            pixelFormat: MetalFrameEncoder.destinationColorPixelFormat,
            width: 16,
            height: 16,
            storageMode: .shared,
            usage: .renderTarget
        )

        #expect(
            throws: MetalFrameEncoderError.unexpectedTargetPixelFormats(
                sceneColor: wrongSceneFormat,
                depth: MetalFrameEncoder.depthPixelFormat,
                destination: MetalFrameEncoder.destinationColorPixelFormat
            )
        ) {
            try MetalFrameEncodingInputs(
                frameResources: frame,
                sceneColorTexture: sceneColor,
                depthTexture: depth,
                destinationTexture: destination,
                clearColor: MTLClearColor(
                    red: 0,
                    green: 0,
                    blue: 0,
                    alpha: 1
                ),
                outputMode: .surface,
                exposure: .validation
            )
        }
    }

    private func makeRenderFrame(instanceCount: Int) -> RenderFrame {
        let snapshot = SimulationPresentationSnapshot(
            cursor: SimulationCursor(
                sessionID: SimulationSessionID(),
                tick: .zero
            ),
            camera: .standard,
            entityPresentations: (0..<instanceCount).map { index in
                EntityPresentationSnapshot(
                    id: EntityID(index: index, generation: 0),
                    position: SIMD3<Float>(Float(index), 0, 0),
                    rotation: nil,
                    scale: nil,
                    meshID: .ball,
                    materialID: .warmDielectric
                )
            }
        )
        return RenderFrame(projecting: snapshot)
    }

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

    private func makeResidencySet(device: any MTLDevice, allocations: [any MTLAllocation]) throws -> any MTLResidencySet {
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
