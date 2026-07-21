import Metal
import Testing
@testable import Engine2

struct MetalResourceStoreTests {
    @MainActor
    @Test func ownsMetal4CompilerQueueAndRequiredStateLibraries() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let store = try MetalResourceStore(
            device: device,
            renderAssetCatalog: RenderAssetCatalog(models: [:])
        )

        let library = try store.shaderLibrary(for: .engine)
        let surfacePipeline = try store.renderPipelineState(for: .modelSurface)
        let normalPipeline = try store.renderPipelineState(
            for: .modelNormalDiagnostic
        )
        let depthStencil = try store.depthStencilState(for: .opaque)
        let argumentTable = try store.argumentTable(for: .model)

        #expect(store.device.registryID == device.registryID)
        #expect(store.compiler.device.registryID == device.registryID)
        #expect(library.functionNames.contains("modelVertex"))
        #expect(library.functionNames.contains("modelFragment"))
        #expect(library.functionNames.contains("modelNormalDiagnosticFragment"))
        #expect(surfacePipeline.label == "USD Model Surface Pipeline")
        #expect(normalPipeline.label == "USD Model Normal Diagnostic Pipeline")
        #expect(depthStencil.label == "Opaque Depth")
        #expect(argumentTable.label == "USD Mesh Argument Table")
    }

    @MainActor
    @Test func opaqueDepthDescriptorWritesOnlyNearerFragments() {
        let descriptor = MetalResourceStore.makeDepthStencilDescriptor(
            for: .opaque
        )

        #expect(descriptor.label == "Opaque Depth")
        #expect(descriptor.depthCompareFunction == .less)
        #expect(descriptor.isDepthWriteEnabled)
    }

    @MainActor
    @Test func repeatedLookupReturnsTheRetainedResource() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let store = try MetalResourceStore(
            device: device,
            renderAssetCatalog: RenderAssetCatalog(models: [:])
        )

        let first = try store.shaderLibrary(for: .engine)
        let second = try store.shaderLibrary(for: .engine)

        #expect(first as AnyObject === second as AnyObject)
    }

    @MainActor
    @Test func residencySetsSeparateStaticAndPerFrameAllocations() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let store = try MetalResourceStore(
            device: device,
            renderAssetCatalog: BasicGameContent().renderAssetCatalog,
            frameCount: 2
        )
        let model = try #require(store.model(for: .ball))

        #expect(
            store.residency.staticAssets.allocationCount ==
                model.allocations.count
        )
        #expect(store.residency.frameResources.allocationCount == 2)

        for allocation in model.allocations {
            #expect(
                store.residency.staticAssets.containsAllocation(allocation)
            )
            #expect(
                !store.residency.frameResources.containsAllocation(allocation)
            )
        }
    }
}
