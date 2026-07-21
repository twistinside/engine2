import Dispatch
import CoreGraphics
import Metal
import simd
import Testing
@testable import Engine2

struct MetalDepthRenderingTests {
    @MainActor
    @Test func nearerTriangleWinsForBothProjectionsRegardlessOfSubmissionOrder() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let resources = try MetalResourceStore(
            device: device,
            renderAssetCatalog: .materialOnlyTestCatalog,
            frameCount: 1
        )

        let cameras = [
            Camera(),
            Camera(
                position: SIMD3<Float>(0, 0, 8),
                orthographicHeight: 8,
                nearPlane: 1,
                farPlane: 20
            )
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
            expectLinearRGBA(
                nearThenFar,
                approximately: SIMD4<Float>(1, 0.5, 0.5, 1)
            )
        }
    }

    @MainActor
    @Test func normalDiagnosticEncodesNormalizedViewSpaceDirection() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let resources = try MetalResourceStore(
            device: device,
            renderAssetCatalog: .materialOnlyTestCatalog,
            frameCount: 1
        )
        let pixel = try renderCenterPixel(
            drawOrder: [0],
            nearNormal: SIMD3<Float>(1, 0, 0),
            resources: resources
        )

        // View-space +X maps directly to linear RGBA (1, 0.5, 0.5, 1) in the
        // scene target. Presentation transfer is tested separately so this
        // diagnostic remains focused on the model fragment's normalization.
        expectLinearRGBA(
            pixel,
            approximately: SIMD4<Float>(1, 0.5, 0.5, 1)
        )
    }
}

@MainActor
private func renderCenterPixel(
    drawOrder: [Int],
    nearNormal: SIMD3<Float> = SIMD3<Float>(1, 0, 0),
    camera: Camera = Camera(),
    resources: MetalResourceStore
) throws -> SIMD4<Float> {
    let textureSize = 8
    let colorTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: MetalRenderer.sceneColorPixelFormat,
        width: textureSize,
        height: textureSize,
        mipmapped: false
    )
    colorTextureDescriptor.storageMode = .shared
    colorTextureDescriptor.usage = [.renderTarget, .shaderRead]

    let depthTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: MetalRenderer.depthPixelFormat,
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
    let farVertexBuffer = try makeTriangleBuffer(
        normal: SIMD3<Float>(0, 1, 0),
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

    let instances = [
        RenderInstance(
            meshID: .ball,
            materialID: .warmDielectric,
            transform: Transform(
                position: SIMD3<Float>(0, 0, 0),
                scale: SIMD3<Float>(4, 4, 1)
            )
        ),
        RenderInstance(
            meshID: .ball,
            materialID: .warmDielectric,
            transform: Transform(
                position: SIMD3<Float>(0, 0, -2),
                scale: SIMD3<Float>(4, 4, 1)
            )
        )
    ]
    let frame = try #require(resources.frames.first)
    frame.commandAllocator.reset()
    let instanceCount = frame.write(
        instances,
        materialDescriptions: try instances.map {
            try resources.materialDescription(for: $0.materialID)
        },
        camera: camera,
        drawableSize: CGSize(width: textureSize, height: textureSize)
    )
    #expect(instanceCount == instances.count)

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
    renderPass.depthAttachment.clearDepth = MetalRenderer.clearDepth

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
        try resources.renderPipelineState(for: .modelNormalDiagnostic)
    )
    encoder.setDepthStencilState(
        try resources.depthStencilState(for: .opaque)
    )

    let argumentTable = try resources.argumentTable(for: .model)
    for instanceIndex in drawOrder {
        argumentTable.setAddress(
            vertexBuffers[instanceIndex].gpuAddress,
            index: 0
        )
        argumentTable.setAddress(
            frame.instanceBuffer.gpuAddress
                + UInt64(instanceIndex * MemoryLayout<GPUInstance>.stride),
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
    return SIMD4<Float>(
        Float(pixel[0]),
        Float(pixel[1]),
        Float(pixel[2]),
        Float(pixel[3])
    )
}

private func makeTriangleBuffer(
    normal: SIMD3<Float>,
    device: any MTLDevice
) throws -> any MTLBuffer {
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

private func expectLinearRGBA(
    _ actual: SIMD4<Float>,
    approximately expected: SIMD4<Float>,
    maximumHalfULPDistance: Int = 1
) {
    for componentIndex in 0..<4 {
        let actualHalf = Float16(actual[componentIndex])
        let expectedHalf = Float16(expected[componentIndex])
        let ulpDistance = abs(
            Int(actualHalf.bitPattern) - Int(expectedHalf.bitPattern)
        )
        #expect(ulpDistance <= maximumHalfULPDistance)
    }
}
