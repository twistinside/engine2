import CoreGraphics
import Dispatch
import Metal
import simd
@testable import Engine2

/// Test-only Metal 4 renderer for the production scene and presentation phases.
///
/// The harness uses the application's model shaders, pipelines, argument-table
/// layouts, parameter buffers, producer barrier, and presentation encoder. Its
/// attachments are CPU-visible solely so tests can inspect the exact value on
/// each side of the HDR boundary; their pixel formats and usage match the
/// production path.
@MainActor
final class MetalHDRPipelineTestRenderer {
    static let width = 65
    static let height = 65

    private static let camera = Camera(
        position: SIMD3<Float>(0, 0, 1),
        orthographicHeight: 2,
        nearPlane: 0.1,
        farPlane: 10
    )

    private let resources: MetalResourceStore
    private let frame: FrameResources
    private let pbrPipeline: any MTLRenderPipelineState
    private let normalPipeline: any MTLRenderPipelineState
    private let depthStencilState: any MTLDepthStencilState
    private let modelArgumentTable: any MTL4ArgumentTable
    private let pbrSceneArgumentTable: any MTL4ArgumentTable
    private let hdrFramePass: MetalHDRFramePass
    private var canSubmit = true

    init() throws {
        let resources = try MetalResourceStore(
            renderAssetCatalog: RenderAssetCatalog(models: [:]),
            frameCount: 1
        )
        guard let frame = resources.frames.first else {
            throw MetalHDRPipelineTestRendererError.missingFrame
        }

        self.resources = resources
        self.frame = frame
        self.pbrPipeline = try resources.renderPipelineState(for: .modelPBR)
        self.normalPipeline = try resources.renderPipelineState(
            for: .modelNormalDiagnostic
        )
        self.depthStencilState = try resources.depthStencilState(for: .opaque)
        self.modelArgumentTable = try resources.argumentTable(for: .model)
        self.pbrSceneArgumentTable = try resources.argumentTable(for: .pbrScene)
        self.hdrFramePass = try MetalHDRFramePass(resources: resources)
    }

    /// Executes the visible two-phase path and returns its center samples.
    ///
    /// A 65-pixel odd extent places one sample exactly at view-space x/y zero.
    /// With the orthographic camera, the center has `N = V = L = +Z` for the
    /// validation surface, making its half-float BRDF result independently
    /// calculable. A caller-supplied normal lets the same geometry prove that
    /// the diagnostic presentation mode bypasses exposure and tone mapping.
    func render(
        outputMode: RenderOutputMode,
        normal: SIMD3<Float> = SIMD3<Float>(0, 0, 1),
        exposure: ManualExposure = .validation
    ) throws -> MetalHDRPipelineTestResult {
        guard canSubmit else {
            throw MetalHDRPipelineTestRendererError.unusableAfterTimeout
        }

        // One frame slot deliberately mirrors the production back-pressure
        // rule. Queue feedback, not the CPU readback, releases this ownership.
        frame.waitUntilAvailable()
        var submitted = false
        defer {
            if !submitted {
                frame.markAvailable()
            }
        }

        let vertexBuffer = try makeTriangleBuffer(normal: normal)
        let sceneTexture = try makeSceneTexture()
        let depthTexture = try makeDepthTexture()
        let presentedTexture = try makePresentedTexture()
        let residencySet = try makeResidencySet(
            allocations: [
                vertexBuffer as any MTLAllocation,
                sceneTexture as any MTLAllocation,
                depthTexture as any MTLAllocation,
                presentedTexture as any MTLAllocation
            ]
        )

        frame.commandAllocator.reset()
        let instance = RenderInstance(
            meshID: .ball,
            transform: Transform()
        )
        let instanceCount = frame.write(
            [instance],
            camera: Self.camera,
            drawableSize: CGSize(width: Self.width, height: Self.height),
            exposure: exposure
        )
        precondition(
            instanceCount == 1,
            "The HDR pipeline proof requires exactly one test triangle."
        )

        guard let commandBuffer = resources.device.makeCommandBuffer() else {
            throw MetalHDRPipelineTestRendererError.missingCommandBuffer
        }
        commandBuffer.beginCommandBuffer(allocator: frame.commandAllocator)

        // Metal 4 clears command-buffer-local residency at every begin. Attach
        // the committed set after beginning this exact submission and retain
        // both the set and its allocations through asynchronous feedback.
        commandBuffer.useResidencySet(residencySet)

        // Use the production frame-pass orchestration. The test supplies only
        // its analytic geometry, so attachment policy, the Metal 4 producer
        // barrier, and presentation ordering cannot drift from the app path.
        try hdrFramePass.encode(
            sceneColorTexture: sceneTexture,
            depthTexture: depthTexture,
            destinationTexture: presentedTexture,
            clearColor: MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1),
            presentationParametersBuffer: frame.hdrPresentationParametersBuffer,
            outputMode: outputMode,
            into: commandBuffer
        ) { sceneEncoder in
            switch outputMode {
            case .surface:
                sceneEncoder.setRenderPipelineState(pbrPipeline)

            case .viewSpaceNormals:
                sceneEncoder.setRenderPipelineState(normalPipeline)
            }
            sceneEncoder.setDepthStencilState(depthStencilState)

            modelArgumentTable.setAddress(vertexBuffer.gpuAddress, index: 0)
            modelArgumentTable.setAddress(
                frame.instanceBuffer.gpuAddress,
                index: 1
            )
            sceneEncoder.setArgumentTable(modelArgumentTable, stages: .vertex)

            pbrSceneArgumentTable.setAddress(
                frame.pbrSceneParametersBuffer.gpuAddress,
                index: 2
            )
            sceneEncoder.setArgumentTable(
                pbrSceneArgumentTable,
                stages: .fragment
            )
            sceneEncoder.drawPrimitives(
                primitiveType: .triangle,
                vertexStart: 0,
                vertexCount: 3
            )
        }
        commandBuffer.endCommandBuffer()

        let submission = MetalOffscreenTestSubmission(
            retaining: [
                self as AnyObject,
                vertexBuffer as AnyObject,
                sceneTexture as AnyObject,
                depthTexture as AnyObject,
                presentedTexture as AnyObject,
                residencySet as AnyObject
            ]
        )
        let commitOptions = MTL4CommitOptions()
        let submittedFrame = frame
        commitOptions.addFeedbackHandler { feedback in
            // Release mutable frame state only after Metal has finished with
            // it, regardless of whether the submitted work succeeded.
            submittedFrame.markAvailable()
            submission.complete(feedbackError: feedback.error)
        }
        resources.commandQueue.commit([commandBuffer], options: commitOptions)
        submitted = true

        do {
            try submission.waitForCompletion(timeout: .now() + 5)
        } catch MetalOffscreenTestSubmissionError.timedOut {
            // Feedback still retains every exact resource. Prevent this object
            // from resetting the allocator or overwriting frame buffers while
            // the timed-out submission may remain live.
            canSubmit = false
            throw MetalHDRPipelineTestRendererError.timedOut
        }

        return MetalHDRPipelineTestResult(
            sceneLinearRGBA: readSceneCenterPixel(from: sceneTexture),
            presentedBGRA8: readPresentedCenterPixel(from: presentedTexture)
        )
    }

    private func makeTriangleBuffer(
        normal: SIMD3<Float>
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
            interleaved.append(.zero) // The PBR path ignores vertex color.
            interleaved.append(normal)
        }

        let buffer: (any MTLBuffer)? = interleaved.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else {
                return nil
            }
            return resources.device.makeBuffer(
                bytes: baseAddress,
                length: bytes.count,
                options: [.storageModeShared]
            )
        }
        guard let buffer else {
            throw MetalHDRPipelineTestRendererError.missingVertexBuffer
        }
        return buffer
    }

    private func makeSceneTexture() throws -> any MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: MetalRenderer.sceneColorPixelFormat,
            width: Self.width,
            height: Self.height,
            mipmapped: false
        )
        // Production uses private storage. Shared storage is the one deliberate
        // test seam: it preserves format, render-target writes, shader reads,
        // and synchronization while allowing deterministic CPU inspection.
        descriptor.storageMode = .shared
        descriptor.usage = [.renderTarget, .shaderRead]
        guard let texture = resources.device.makeTexture(descriptor: descriptor) else {
            throw MetalHDRPipelineTestRendererError.missingSceneTexture
        }
        return texture
    }

    private func makeDepthTexture() throws -> any MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: MetalRenderer.depthPixelFormat,
            width: Self.width,
            height: Self.height,
            mipmapped: false
        )
        descriptor.storageMode = .private
        descriptor.usage = [.renderTarget]
        guard let texture = resources.device.makeTexture(descriptor: descriptor) else {
            throw MetalHDRPipelineTestRendererError.missingDepthTexture
        }
        return texture
    }

    private func makePresentedTexture() throws -> any MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: MetalRenderer.colorPixelFormat,
            width: Self.width,
            height: Self.height,
            mipmapped: false
        )
        descriptor.storageMode = .shared
        descriptor.usage = [.renderTarget]
        guard let texture = resources.device.makeTexture(descriptor: descriptor) else {
            throw MetalHDRPipelineTestRendererError.missingPresentedTexture
        }
        return texture
    }

    private func makeResidencySet(
        allocations: [any MTLAllocation]
    ) throws -> any MTLResidencySet {
        let descriptor = MTLResidencySetDescriptor()
        descriptor.label = "Visible HDR Pipeline Proof Resources"
        descriptor.initialCapacity = allocations.count
        let residencySet = try resources.device.makeResidencySet(
            descriptor: descriptor
        )
        for allocation in allocations {
            residencySet.addAllocation(allocation)
        }
        residencySet.commit()
        return residencySet
    }

    private func readSceneCenterPixel(
        from texture: any MTLTexture
    ) -> SIMD4<Float> {
        var components = [Float16](repeating: 0, count: 4)
        components.withUnsafeMutableBytes { bytes in
            texture.getBytes(
                bytes.baseAddress!,
                bytesPerRow: 4 * MemoryLayout<Float16>.stride,
                from: Self.centerRegion,
                mipmapLevel: 0
            )
        }
        return SIMD4<Float>(
            Float(components[0]),
            Float(components[1]),
            Float(components[2]),
            Float(components[3])
        )
    }

    private func readPresentedCenterPixel(
        from texture: any MTLTexture
    ) -> SIMD4<UInt8> {
        var components = [UInt8](repeating: 0, count: 4)
        components.withUnsafeMutableBytes { bytes in
            texture.getBytes(
                bytes.baseAddress!,
                bytesPerRow: 4,
                from: Self.centerRegion,
                mipmapLevel: 0
            )
        }
        return SIMD4<UInt8>(
            components[0],
            components[1],
            components[2],
            components[3]
        )
    }

    private static var centerRegion: MTLRegion {
        MTLRegionMake2D(width / 2, height / 2, 1, 1)
    }
}
