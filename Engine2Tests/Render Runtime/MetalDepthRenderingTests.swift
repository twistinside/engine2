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
            renderAssetCatalog: RenderAssetCatalog(models: [:]),
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
            #expect(nearThenFar[0] < 8)   // blue byte in BGRA storage
            #expect(nearThenFar[1] < 8)   // green byte
            #expect(nearThenFar[2] > 247) // red byte from nearer triangle
            #expect(nearThenFar[3] > 247) // opaque alpha
        }
    }

    @MainActor
    @Test func normalDiagnosticEncodesNormalizedViewSpaceDirection() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let resources = try MetalResourceStore(
            device: device,
            renderAssetCatalog: RenderAssetCatalog(models: [:]),
            frameCount: 1
        )
        let pixel = try renderCenterPixel(
            drawOrder: [0],
            pipelineID: .modelNormalDiagnostic,
            nearNormal: SIMD3<Float>(1, 0, 0),
            resources: resources
        )

        // View-space +X maps to linear RGB (1, 0.5, 0.5). The sRGB target
        // transfer-encodes the two 0.5 channels to approximately 188.
        #expect((180...195).contains(Int(pixel[0])))
        #expect((180...195).contains(Int(pixel[1])))
        #expect(pixel[2] > 247)
        #expect(pixel[3] > 247)
    }
}

@MainActor
private func renderCenterPixel(
    drawOrder: [Int],
    pipelineID: MetalRenderPipelineID = .modelSurface,
    nearNormal: SIMD3<Float> = SIMD3<Float>(0, 0, 1),
    camera: Camera = Camera(),
    resources: MetalResourceStore
) throws -> [UInt8] {
    let textureSize = 8
    let colorTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: MetalRenderer.colorPixelFormat,
        width: textureSize,
        height: textureSize,
        mipmapped: false
    )
    colorTextureDescriptor.storageMode = .shared
    colorTextureDescriptor.usage = [.renderTarget]

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
        color: SIMD3<Float>(1, 0, 0),
        normal: nearNormal,
        device: resources.device
    )
    let farVertexBuffer = try makeTriangleBuffer(
        color: SIMD3<Float>(0, 1, 0),
        normal: SIMD3<Float>(0, 0, 1),
        device: resources.device
    )
    let vertexBuffers = [nearVertexBuffer, farVertexBuffer]

    // Metal 4 does not make resources resident implicitly. Add every transient
    // allocation to a set registered with this test queue before encoding it;
    // explicit object lifetime is handled separately across the wait below.
    for allocation in [
        colorTexture as any MTLAllocation,
        depthTexture as any MTLAllocation,
        nearVertexBuffer as any MTLAllocation,
        farVertexBuffer as any MTLAllocation
    ] {
        resources.residency.addStaticAllocation(allocation)
    }
    resources.residency.commitStaticAssets()

    let instances = [
        RenderInstance(
            meshID: .ball,
            transform: Transform(
                position: SIMD3<Float>(0, 0, 0),
                scale: SIMD3<Float>(4, 4, 1)
            )
        ),
        RenderInstance(
            meshID: .ball,
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
    let encoder = try #require(
        commandBuffer.makeRenderCommandEncoder(
            descriptor: renderPass,
            options: []
        )
    )
    encoder.setRenderPipelineState(
        try resources.renderPipelineState(for: pipelineID)
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

    let completion = DispatchSemaphore(value: 0)
    let submission = MetalOffscreenTestSubmission(
        resources: resources,
        colorTexture: colorTexture,
        depthTexture: depthTexture,
        nearVertexBuffer: nearVertexBuffer,
        farVertexBuffer: farVertexBuffer,
        completion: completion
    )
    let commitOptions = MTL4CommitOptions()
    commitOptions.addFeedbackHandler { _ in
        submission.complete()
    }
    resources.commandQueue.commit([commandBuffer], options: commitOptions)

    // A timeout does not release `submission`: the queue's feedback handler
    // owns it independently until the GPU actually completes the workload.
    let waitResult = completion.wait(timeout: .now() + 5)
    guard waitResult == .success else {
        Issue.record("Timed out waiting for the offscreen Metal depth test.")
        return [0, 0, 0, 0]
    }

    var pixel = [UInt8](repeating: 0, count: 4)
    colorTexture.getBytes(
        &pixel,
        bytesPerRow: 4,
        from: MTLRegionMake2D(textureSize / 2, textureSize / 2, 1, 1),
        mipmapLevel: 0
    )
    return pixel
}

private func makeTriangleBuffer(
    color: SIMD3<Float>,
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
        interleaved.append(color)
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
