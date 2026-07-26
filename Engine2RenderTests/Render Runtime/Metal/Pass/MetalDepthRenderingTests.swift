import Dispatch
import CoreGraphics
import Metal
import simd
import Testing
@testable import Engine2

struct MetalDepthRenderingTests {
    @Test func nearerTriangleWinsForBothProjectionsRegardlessOfSubmissionOrder() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let resources = try MetalResourceStore(
            device: device,
            renderAssetCatalog: .materialOnlyTestCatalog,
            frameCount: 1
        )

        let orthographicPosition = SIMD3<Float>(0, 0, 8)
        let orthographicCamera = Camera(
            position: orthographicPosition,
            rotation: Transform.identityRotation,
            projection: .orthographic(
                height: 8,
                near: 1,
                far: 20
            )
        )
        let cameras = [
            .standard,
            orthographicCamera
        ]

        for camera in cameras {
            // Instance zero is closer to the camera than instance one. Render
            // both submission orders so this test distinguishes depth
            // visibility from accidental painter's-algorithm behavior.
            let nearThenFar = try renderCenterPixel(
                drawOrder: [0, 1],
                camera: camera,
                resources: resources
            )
            let farThenNear = try renderCenterPixel(
                drawOrder: [1, 0],
                camera: camera,
                resources: resources
            )

            #expect(nearThenFar == farThenNear)
            let expectedColor = SIMD4<Float>(1, 0.5, 0.5, 1)
            expectLinearRGBA(
                nearThenFar,
                approximately: expectedColor
            )
        }
    }

    @Test func normalDiagnosticEncodesNormalizedViewSpaceDirection() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let resources = try MetalResourceStore(
            device: device,
            renderAssetCatalog: .materialOnlyTestCatalog,
            frameCount: 1
        )
        let nearNormal = SIMD3<Float>(1, 0, 0)
        let pixel = try renderCenterPixel(
            drawOrder: [0],
            nearNormal: nearNormal,
            camera: .standard,
            resources: resources
        )

        // View-space +X maps directly to linear RGBA (1, 0.5, 0.5, 1) in the
        // scene target. Presentation transfer is tested separately so this
        // diagnostic remains focused on the model fragment's normalization.
        let expectedColor = SIMD4<Float>(1, 0.5, 0.5, 1)
        expectLinearRGBA(
            pixel,
            approximately: expectedColor
        )
    }
}

private func renderCenterPixel(
    drawOrder: [Int],
    nearNormal: SIMD3<Float> = SIMD3<Float>(1, 0, 0),
    camera: Camera,
    resources: MetalResourceStore
) throws -> SIMD4<Float> {
    let textureSize = 8
    let colorTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: MetalFrameEncoder.sceneColorPixelFormat,
        width: textureSize,
        height: textureSize,
        mipmapped: false
    )
    colorTextureDescriptor.storageMode = .shared
    colorTextureDescriptor.usage = [.renderTarget, .shaderRead]

    let depthTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: MetalFrameEncoder.depthPixelFormat,
        width: textureSize,
        height: textureSize,
        mipmapped: false
    )
    depthTextureDescriptor.storageMode = .private
    depthTextureDescriptor.usage = [.renderTarget]

    let colorTexture = try #require(
        resources.device.makeTexture(descriptor: colorTextureDescriptor)
    )
    let depthTexture = try #require(
        resources.device.makeTexture(descriptor: depthTextureDescriptor)
    )
    let nearVertexBuffer = try makeTriangleBuffer(
        normal: nearNormal,
        device: resources.device
    )
    let farNormal = SIMD3<Float>(0, 1, 0)
    let farVertexBuffer = try makeTriangleBuffer(
        normal: farNormal,
        device: resources.device
    )
    let vertexBuffers = [nearVertexBuffer, farVertexBuffer]

    // Metal 4 does not make resources resident implicitly. Keep these
    // test-local allocations in a dedicated set attached only to this command
    // buffer instead of mutating the store's long-lived asset residency set.
    let residencyDescriptor = MTLResidencySetDescriptor()
    residencyDescriptor.label = "Depth Proof Resources"
    residencyDescriptor.initialCapacity = 4
    let residencySet = try resources.device.makeResidencySet(
        descriptor: residencyDescriptor
    )
    for allocation in [
        colorTexture as any MTLAllocation,
        depthTexture as any MTLAllocation,
        nearVertexBuffer as any MTLAllocation,
        farVertexBuffer as any MTLAllocation
    ] {
        residencySet.addAllocation(allocation)
    }
    residencySet.commit()

    let sharedScale = SIMD3<Float>(4, 4, 1)
    let nearPosition = SIMD3<Float>(0, 0, 0)
    let nearTransform = Transform(
        position: nearPosition,
        rotation: Transform.identityRotation,
        scale: sharedScale
    )
    let farPosition = SIMD3<Float>(0, 0, -2)
    let farTransform = Transform(
        position: farPosition,
        rotation: Transform.identityRotation,
        scale: sharedScale
    )
    let transforms = [nearTransform, farTransform]
    let frame = try #require(resources.frames.first)
    frame.commandAllocator.reset()
    let sessionID = SimulationSessionID()
    let cursor = SimulationCursor(
        sessionID: sessionID,
        tick: .zero
    )
    let entityPresentations = transforms.enumerated().map { index, transform in
        let id = EntityID(index: index, generation: 0)
        return EntityPresentationSnapshot(
            id: id,
            position: transform.position,
            rotation: transform.rotation,
            scale: transform.scale,
            meshID: .ball,
            materialID: .warmDielectric
        )
    }
    let snapshot = SimulationPresentationSnapshot(
        cursor: cursor,
        camera: camera,
        entityPresentations: entityPresentations
    )
    let renderFrame = RenderFrame(projecting: snapshot)
    let preparedFrame = MetalPreparedFrame(
        renderFrame: renderFrame,
        resources: resources
    )
    let drawableSize = CGSize(width: textureSize, height: textureSize)
    frame.write(
        preparedFrame,
        drawableSize: drawableSize,
        exposure: .validation
    )
    #expect(preparedFrame.instances.count == transforms.count)

    let renderPass = MTL4RenderPassDescriptor()
    renderPass.colorAttachments[0].texture = colorTexture
    renderPass.colorAttachments[0].loadAction = .clear
    renderPass.colorAttachments[0].storeAction = .store
    renderPass.colorAttachments[0].clearColor = MTLClearColor(
        red: 0,
        green: 0,
        blue: 0,
        alpha: 1
    )
    renderPass.depthAttachment.texture = depthTexture
    renderPass.depthAttachment.loadAction = .clear
    renderPass.depthAttachment.storeAction = .dontCare
    renderPass.depthAttachment.clearDepth = MetalFrameEncoder.clearDepth

    let commandBuffer = try #require(resources.device.makeCommandBuffer())
    commandBuffer.beginCommandBuffer(allocator: frame.commandAllocator)
    commandBuffer.useResidencySet(residencySet)
    let encoder = try #require(
        commandBuffer.makeRenderCommandEncoder(
            descriptor: renderPass,
            options: []
        )
    )
    encoder.setRenderPipelineState(
        resources.requiredResources.modelNormalDiagnosticPipeline
    )
    encoder.setDepthStencilState(
        resources.requiredResources.opaqueDepthStencilState
    )

    let argumentTable = resources.requiredResources.modelArgumentTable
    for instanceIndex in drawOrder {
        argumentTable.setAddress(
            vertexBuffers[instanceIndex].gpuAddress,
            index: 0
        )
        let instanceOffset = UInt64(
            instanceIndex * MemoryLayout<GPUInstance>.stride
        )
        let instanceAddress = frame.instanceBuffer.gpuAddress + instanceOffset
        argumentTable.setAddress(
            instanceAddress,
            index: 1
        )
        encoder.setArgumentTable(argumentTable, stages: .vertex)
        encoder.drawPrimitives(
            primitiveType: .triangle,
            vertexStart: 0,
            vertexCount: 3
        )
    }

    encoder.endEncoding()
    commandBuffer.endCommandBuffer()

    let submission = MetalOffscreenTestSubmission(
        retaining: [
            resources as AnyObject,
            colorTexture as AnyObject,
            depthTexture as AnyObject,
            nearVertexBuffer as AnyObject,
            farVertexBuffer as AnyObject,
            residencySet as AnyObject
        ]
    )
    let commitOptions = MTL4CommitOptions()
    commitOptions.addFeedbackHandler { feedback in
        submission.complete(feedbackError: feedback.error)
    }
    resources.commandQueue.commit([commandBuffer], options: commitOptions)

    // Throwing is required here. Returning a sentinel pixel would let the
    // caller reset this store's allocator and rewrite shared inputs even though
    // timed-out GPU work may still reference them. The feedback closure keeps
    // `submission` and its owners alive until Metal truly finishes.
    try submission.waitForCompletion(timeout: .now() + 5)

    var pixel = [Float16](repeating: 0, count: 4)
    pixel.withUnsafeMutableBytes { bytes in
        colorTexture.getBytes(
            bytes.baseAddress!,
            bytesPerRow: 4 * MemoryLayout<Float16>.stride,
            from: MTLRegionMake2D(textureSize / 2, textureSize / 2, 1, 1),
            mipmapLevel: 0
        )
    }
    let red = Float(pixel[0])
    let green = Float(pixel[1])
    let blue = Float(pixel[2])
    let alpha = Float(pixel[3])
    return SIMD4<Float>(
        red,
        green,
        blue,
        alpha
    )
}

private func makeTriangleBuffer(normal: SIMD3<Float>, device: any MTLDevice) throws -> any MTLBuffer {
    let positions = [
        SIMD3<Float>(-1, -1, 0),
        SIMD3<Float>(1, -1, 0),
        SIMD3<Float>(0, 1, 0)
    ]
    var interleaved: [SIMD3<Float>] = []
    interleaved.reserveCapacity(positions.count * 3)

    for position in positions {
        interleaved.append(position)
        // Vertex display color is intentionally irrelevant to this proof. The
        // normal diagnostic gives near and far geometry distinct linear values
        // without retaining the removed unlit surface pathway for a test.
        interleaved.append(.zero)
        interleaved.append(normal)
    }

    let buffer: (any MTLBuffer)? = interleaved.withUnsafeBytes { bytes in
        guard let baseAddress = bytes.baseAddress else {
            return nil
        }

        return device.makeBuffer(
            bytes: baseAddress,
            length: bytes.count,
            options: [.storageModeShared]
        )
    }
    return try #require(buffer)
}

private func expectLinearRGBA(_ actual: SIMD4<Float>, approximately expected: SIMD4<Float>, maximumHalfULPDistance: Int = 1) {
    for componentIndex in 0..<4 {
        let actualHalf = Float16(actual[componentIndex])
        let expectedHalf = Float16(expected[componentIndex])
        let actualBitPattern = Int(actualHalf.bitPattern)
        let expectedBitPattern = Int(expectedHalf.bitPattern)
        let ulpDistance = abs(actualBitPattern - expectedBitPattern)
        #expect(ulpDistance <= maximumHalfULPDistance)
    }
}
