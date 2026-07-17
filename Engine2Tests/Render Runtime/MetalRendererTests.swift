import Metal
import Testing
@testable import Engine2

struct MetalRendererTests {
    @MainActor
    @Test func resourceStoreCreatesConfiguredPipelineAndArgumentTable() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let resources = try MetalResourceStore(
            device: device,
            renderAssetCatalog: RenderAssetCatalog(models: [:])
        )

        let pipeline = try resources.renderPipelineState(for: .model)
        let argumentTable = try resources.argumentTable(for: .model)

        #expect(pipeline.label == "USD Model Pipeline")
        #expect(argumentTable.label == "USD Mesh Argument Table")
    }

    @MainActor
    @Test func createsRequestedFrameResourceRing() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let resources = try MetalResourceStore(
            device: device,
            renderAssetCatalog: RenderAssetCatalog(models: [:]),
            frameCount: 2
        )

        #expect(resources.frames.count == 2)
        #expect(resources.residency.frameResources.allocationCount == 2)
        for frame in resources.frames {
            #expect(frame.instanceBuffer.length > 0)
        }
    }

    @MainActor
    @Test func frameResourcesClampInstancesToBufferCapacity() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let resources = try MetalResourceStore(
            device: device,
            renderAssetCatalog: RenderAssetCatalog(models: [:]),
            frameCount: 1
        )
        let frame = try #require(resources.frames.first)
        let instances = (0..<(FrameResources.maximumInstanceCount + 10)).map {
            RenderInstance(
                meshID: .ball,
                worldPosition: SIMD3<Float>(Float($0), 0, 0)
            )
        }

        let writtenCount = frame.write(
            instances,
            camera: Camera(),
            drawableSize: CGSize(width: 1_920, height: 1_080)
        )

        #expect(writtenCount == FrameResources.maximumInstanceCount)
    }
}
