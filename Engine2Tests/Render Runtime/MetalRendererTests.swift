import CoreGraphics
import Metal
import MetalKit
import Testing
@testable import Engine2

struct MetalRendererTests {
    @MainActor
    @Test func resourceStoreCreatesEveryRendererPipelineAndArgumentTable() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let resources = try MetalResourceStore(
            device: device,
            renderAssetCatalog: .materialOnlyTestCatalog
        )

        let pbrPipeline = try resources.renderPipelineState(for: .modelPBR)
        let normalPipeline = try resources.renderPipelineState(
            for: .modelNormalDiagnostic
        )
        let toneMappedPresentationPipeline = try resources.renderPipelineState(
            for: .hdrToneMappedPresentation
        )
        let linearPresentationPipeline = try resources.renderPipelineState(
            for: .linearPresentation
        )
        let modelArgumentTable = try resources.argumentTable(for: .model)
        let pbrSceneArgumentTable = try resources.argumentTable(for: .pbrScene)
        let presentationArgumentTable = try resources.argumentTable(
            for: .hdrPresentation
        )

        // The scene phase has one lit surface pipeline and one diagnostic
        // sibling. Presentation is a separate phase with tone-mapped and
        // linear variants, so all four states must exist before drawing.
        #expect(pbrPipeline.label == "USD Model PBR Pipeline")
        #expect(normalPipeline.label == "USD Model Normal Diagnostic Pipeline")
        #expect(
            toneMappedPresentationPipeline.label ==
                "HDR Tone-Mapped Presentation Pipeline"
        )
        #expect(
            linearPresentationPipeline.label ==
                "Linear Diagnostic Presentation Pipeline"
        )

        // Geometry, scene lighting, and HDR presentation intentionally use
        // separate binding layouts rather than one oversized mutable table.
        #expect(modelArgumentTable.label == "USD Mesh Argument Table")
        #expect(pbrSceneArgumentTable.label == "PBR Scene Argument Table")
        #expect(
            presentationArgumentTable.label ==
                "HDR Presentation Argument Table"
        )
    }

    @MainActor
    @Test func sceneCoordinatorRetainsAuthoredContentPreflightFailure() throws {
        let completeCatalog = BasicGameContent().renderAssetCatalog
        let incompleteCatalog = RenderAssetCatalog(
            models: completeCatalog.models,
            materials: [
                .warmDielectric: try #require(
                    completeCatalog.materials[.warmDielectric]
                )
            ]
        )
        let simulation = SimulationRuntime()

        let coordinator = MetalSceneView.Coordinator(
            renderAssetCatalog: incompleteCatalog,
            presentationSource: simulation,
            outputMode: .surface
        )
        let error = try #require(
            coordinator.latestRenderError as? RenderAssetCatalogError
        )

        // Store construction rejects the complete missing vocabulary before
        // pipelines, models, or a renderer are created. The bridge retains the
        // exact error so App diagnostics do not see only an unexplained black
        // view, and no fallback material can enter a draw.
        #expect(
            error == .missingMaterialDescriptions(
                MaterialID.allCases.filter { $0 != .warmDielectric }
            )
        )
        #expect(coordinator.renderer == nil)
    }

    @MainActor
    @Test func publishedMaterialSceneReachesEveryProductionModelDraw() throws {
        let scene = PublishedMaterialValidationScene()
        let device = try #require(MTLCreateSystemDefaultDevice())
        let resources = try MetalResourceStore(
            device: device,
            renderAssetCatalog: scene.catalog,
            frameCount: 1
        )
        let instances = scene.renderFrame.instances
        var visitedIndices: [Int] = []
        var visitedMaterialIDs: [MaterialID] = []
        var decodedMeshCounts: [Int] = []

        // Call the same ordered lookup seam as `MetalRenderer.draw(in:)`.
        // Together with the GPU binding proof, this closes the join between the
        // real projected frame, its shared MeshID, and all six visible draws.
        MetalRenderer.forEachRenderableModel(
            in: instances,
            instanceCount: instances.count,
            resources: resources
        ) { instanceIndex, model in
            visitedIndices.append(instanceIndex)
            visitedMaterialIDs.append(instances[instanceIndex].materialID)
            decodedMeshCounts.append(model.meshes.count)
        }

        #expect(instances.count == 6)
        #expect(instances.allSatisfy { $0.meshID == .ball })
        #expect(visitedIndices == Array(instances.indices))
        #expect(visitedMaterialIDs == scene.materialIDs)
        #expect(decodedMeshCounts.allSatisfy { $0 > 0 })
    }

    @MainActor
    @Test func renderTargetConfigurationSeparatesHDRSceneFromSRGBPresentation() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let view = MTKView(frame: .zero, device: device)

        MetalRenderer.configureRenderTargets(on: view)

        // Scene radiance remains linear half-float until the second phase.
        // Only that presentation phase targets the display's sRGB drawable.
        #expect(MetalRenderer.sceneColorPixelFormat == .rgba16Float)
        #expect(MetalRenderer.colorPixelFormat == .bgra8Unorm_srgb)
        #expect(view.colorPixelFormat == .bgra8Unorm_srgb)
        #expect(view.depthStencilPixelFormat == .depth32Float)
        #expect(view.clearDepth == 1)

        // The shader returns display-linear tone-mapped values. Declaring sRGB
        // here lets the drawable apply the sole transfer encoding and gives
        // Core Animation explicit color-matching metadata.
        let configuredColorSpace = try #require(view.colorspace)
        let configuredColorSpaceName = try #require(configuredColorSpace.name)
        #expect(configuredColorSpaceName == CGColorSpace.sRGB)
    }

    @MainActor
    @Test func createsRequestedFrameResourceRing() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let resources = try MetalResourceStore(
            device: device,
            renderAssetCatalog: .materialOnlyTestCatalog,
            frameCount: 2
        )

        #expect(resources.frames.count == 2)
        #expect(resources.residency.frameResources.allocationCount == 6)
        for frame in resources.frames {
            // Each reusable slot owns all three CPU-written buffers that can be
            // read by an in-flight command buffer. Keeping them in the same
            // ring prevents transforms, lighting, or exposure from being
            // overwritten while the GPU still consumes an earlier frame.
            #expect(
                frame.instanceBuffer.length ==
                    MemoryLayout<GPUInstance>.stride
                        * FrameResources.maximumInstanceCount
            )
            #expect(
                frame.pbrSceneParametersBuffer.length ==
                    MemoryLayout<PBRSceneParameters>.stride
            )
            #expect(
                frame.hdrPresentationParametersBuffer.length ==
                    MemoryLayout<HDRPresentationParameters>.stride
            )
            #expect(frame.hdrSceneTarget == nil)
        }
    }

    @MainActor
    @Test func frameResourceReusesAndResizesItsHDRSceneTarget() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let resources = try MetalResourceStore(
            device: device,
            renderAssetCatalog: .materialOnlyTestCatalog,
            frameCount: 1
        )
        let frame = try #require(resources.frames.first)

        // Target replacement is legal only while this reusable slot is owned
        // by the caller, matching the production draw path's semaphore rule.
        frame.waitUntilAvailable()
        defer { frame.markAvailable() }

        let initial = try frame.prepareHDRSceneTarget(
            device: device,
            width: 320,
            height: 180
        )

        // The scene allocation preserves radiance above one and supports both
        // sides of the explicit scene-write/presentation-read dependency.
        #expect(initial.width == 320)
        #expect(initial.height == 180)
        #expect(initial.texture.pixelFormat == .rgba16Float)
        #expect(initial.texture.storageMode == .private)
        #expect(initial.texture.usage.contains(.renderTarget))
        #expect(initial.texture.usage.contains(.shaderRead))
        #expect(initial.residencySet.allocationCount == 1)
        #expect(initial.residencySet.containsAllocation(initial.texture))

        let repeated = try frame.prepareHDRSceneTarget(
            device: device,
            width: 320,
            height: 180
        )

        // An unchanged drawable size must not churn textures or residency sets.
        #expect(initial === repeated)

        let resized = try frame.prepareHDRSceneTarget(
            device: device,
            width: 640,
            height: 360
        )

        // No command was submitted in this test, so the slot may replace its
        // generation immediately. The old local value remains a self-contained
        // target and residency set just as an in-flight submission would retain
        // it until feedback.
        #expect(initial !== resized)
        #expect(resized.width == 640)
        #expect(resized.height == 360)
        #expect(frame.hdrSceneTarget === resized)
        #expect(resized.residencySet.containsAllocation(resized.texture))
        #expect(initial.residencySet.containsAllocation(initial.texture))
        #expect(!initial.residencySet.containsAllocation(resized.texture))
    }

    @MainActor
    @Test func sceneRenderPassStoresHDRColorAndUsesTransientOrdinaryDepth() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let sceneColorTexture = try makeTexture(
            device: device,
            pixelFormat: .rgba16Float,
            usage: [.renderTarget, .shaderRead]
        )
        let depthTexture = try makeTexture(
            device: device,
            pixelFormat: .depth32Float,
            usage: .renderTarget
        )
        let clearColor = MTLClearColor(
            red: 0.125,
            green: 0.25,
            blue: 0.5,
            alpha: 1
        )

        let descriptor = MetalHDRFramePass.makeSceneRenderPassDescriptor(
            sceneColorTexture: sceneColorTexture,
            depthTexture: depthTexture,
            clearColor: clearColor
        )
        let colorAttachment = try #require(descriptor.colorAttachments[0])
        let attachedColorTexture = try #require(colorAttachment.texture)
        let attachedDepthTexture = try #require(
            descriptor.depthAttachment.texture
        )

        // Presentation samples scene color in a later encoder, so the HDR
        // attachment must be stored. Depth has no later consumer and should be
        // discarded after enforcing ordinary `.less` depth during the scene.
        #expect(attachedColorTexture as AnyObject === sceneColorTexture as AnyObject)
        #expect(colorAttachment.loadAction == .clear)
        #expect(colorAttachment.storeAction == .store)
        #expect(colorAttachment.clearColor.red == clearColor.red)
        #expect(colorAttachment.clearColor.green == clearColor.green)
        #expect(colorAttachment.clearColor.blue == clearColor.blue)
        #expect(colorAttachment.clearColor.alpha == clearColor.alpha)
        #expect(attachedDepthTexture as AnyObject === depthTexture as AnyObject)
        #expect(descriptor.depthAttachment.loadAction == .clear)
        #expect(descriptor.depthAttachment.storeAction == .dontCare)
        #expect(descriptor.depthAttachment.clearDepth == MetalRenderer.clearDepth)
    }

    @MainActor
    @Test func presentationRenderPassStoresOnlyTheSRGBDrawable() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let drawableTexture = try makeTexture(
            device: device,
            pixelFormat: .bgra8Unorm_srgb,
            usage: .renderTarget
        )

        let descriptor = MetalHDRPresentationPass.makeRenderPassDescriptor(
            destinationTexture: drawableTexture
        )
        let colorAttachment = try #require(descriptor.colorAttachments[0])
        let attachedTexture = try #require(colorAttachment.texture)

        // The full-screen phase overwrites the drawable and stores it for
        // presentation. It neither needs nor inherits the scene depth target.
        #expect(attachedTexture as AnyObject === drawableTexture as AnyObject)
        #expect(attachedTexture.pixelFormat == .bgra8Unorm_srgb)
        #expect(colorAttachment.loadAction == .clear)
        #expect(colorAttachment.storeAction == .store)
        #expect(colorAttachment.clearColor.red == 0)
        #expect(colorAttachment.clearColor.green == 0)
        #expect(colorAttachment.clearColor.blue == 0)
        #expect(colorAttachment.clearColor.alpha == 1)
        #expect(descriptor.depthAttachment.texture == nil)
    }

    @MainActor
    @Test func frameResourcesClampInstancesToBufferCapacity() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let resources = try MetalResourceStore(
            device: device,
            renderAssetCatalog: .materialOnlyTestCatalog,
            frameCount: 1
        )
        let frame = try #require(resources.frames.first)
        let instances = (0..<(FrameResources.maximumInstanceCount + 10)).map {
            RenderInstance(
                meshID: .ball,
                materialID: .warmDielectric,
                worldPosition: SIMD3<Float>(Float($0), 0, 0)
            )
        }

        let writtenCount = frame.write(
            instances,
            materialDescriptions: Array(
                repeating: try resources.materialDescription(
                    for: .warmDielectric
                ),
                count: FrameResources.maximumInstanceCount
            ),
            camera: Camera(),
            drawableSize: CGSize(width: 1_920, height: 1_080)
        )

        #expect(writtenCount == FrameResources.maximumInstanceCount)
    }

    @MainActor
    private func makeTexture(
        device: any MTLDevice,
        pixelFormat: MTLPixelFormat,
        usage: MTLTextureUsage
    ) throws -> any MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: 16,
            height: 16,
            mipmapped: false
        )
        descriptor.storageMode = .private
        descriptor.usage = usage
        return try #require(device.makeTexture(descriptor: descriptor))
    }
}
