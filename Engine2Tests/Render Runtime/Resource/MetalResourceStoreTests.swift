import Metal
import Testing
@testable import Engine2

struct MetalResourceStoreTests {
    @MainActor
    @Test func ownsMetal4CompilerQueueAndRequiredStateLibraries() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let store = try MetalResourceStore(
            device: device,
            renderAssetCatalog: .materialOnlyTestCatalog
        )

        let library = try store.shaderLibrary(for: .engine)
        let pbrPipeline = try store.renderPipelineState(for: .modelPBR)
        let normalPipeline = try store.renderPipelineState(
            for: .modelNormalDiagnostic
        )
        let toneMappedPresentationPipeline = try store.renderPipelineState(
            for: .hdrToneMappedPresentation
        )
        let linearPresentationPipeline = try store.renderPipelineState(
            for: .linearPresentation
        )
        let depthStencil = try store.depthStencilState(for: .opaque)
        let modelArgumentTable = try store.argumentTable(for: .model)
        let pbrSceneArgumentTable = try store.argumentTable(for: .pbrScene)
        let presentationArgumentTable = try store.argumentTable(
            for: .hdrPresentation
        )

        #expect(store.device.registryID == device.registryID)
        #expect(store.compiler.device.registryID == device.registryID)

        // Every entry point required by both render phases must live in the
        // eagerly loaded engine library. A missing function therefore fails
        // store construction rather than first appearing in the draw path.
        #expect(library.functionNames.contains("modelVertex"))
        #expect(library.functionNames.contains("modelPBRFragment"))
        #expect(library.functionNames.contains("modelNormalDiagnosticFragment"))
        #expect(library.functionNames.contains("hdrPresentationVertex"))
        #expect(
            library.functionNames.contains(
                "hdrToneMappedPresentationFragment"
            )
        )
        #expect(library.functionNames.contains("linearPresentationFragment"))

        // Scene pipelines compile against linear HDR color, while the two
        // presentation pipelines compile against the sRGB drawable format.
        // Successful eager compilation plus these closed identities protects
        // that split even though pipeline state hides its source descriptor.
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
        #expect(depthStencil.label == "Opaque Depth")

        // Each phase uses only the binding vocabulary it owns: model geometry,
        // PBR frame constants, or HDR source/exposure presentation inputs.
        #expect(modelArgumentTable.label == "USD Mesh Argument Table")
        #expect(pbrSceneArgumentTable.label == "PBR Scene Argument Table")
        #expect(
            presentationArgumentTable.label ==
                "HDR Presentation Argument Table"
        )
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
            renderAssetCatalog: .materialOnlyTestCatalog
        )

        let first = try store.shaderLibrary(for: .engine)
        let second = try store.shaderLibrary(for: .engine)

        #expect(first as AnyObject === second as AnyObject)
    }

    @MainActor
    @Test func retainsExactAuthoredMaterialDescriptions() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let catalog = BasicGameContent().renderAssetCatalog
        let store = try MetalResourceStore(
            device: device,
            renderAssetCatalog: catalog
        )

        // Material identities cross the runtime boundary, while the retained
        // factor descriptions remain a CPU-side Render resource until a frame
        // packs them into its private instance buffer.
        for materialID in MaterialID.allCases {
            let expected = try #require(catalog.materials[materialID])
            #expect(
                try store.materialDescription(for: materialID)
                    == expected
            )
        }
    }

    @MainActor
    @Test func rejectsIncompleteMaterialContentBeforeBuildingTheStore() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let incompleteCatalog = RenderAssetCatalog(
            models: [:],
            materials: [
                .warmDielectric: try #require(
                    BasicGameContent().renderAssetCatalog.materials[
                        .warmDielectric
                    ]
                )
            ]
        )

        do {
            _ = try MetalResourceStore(
                device: device,
                renderAssetCatalog: incompleteCatalog
            )
            Issue.record("Expected incomplete authored material content to fail")
        } catch let error as RenderAssetCatalogError {
            #expect(
                error == .missingMaterialDescriptions(
                    MaterialID.allCases.filter { $0 != .warmDielectric }
                )
            )
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
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
        #expect(store.residency.frameResources.allocationCount == 6)

        for allocation in model.allocations {
            #expect(
                store.residency.staticAssets.containsAllocation(allocation)
            )
            #expect(
                !store.residency.frameResources.containsAllocation(allocation)
            )
        }

        for frame in store.frames {
            let frameAllocations: [any MTLAllocation] = [
                frame.instanceBuffer,
                frame.pbrSceneParametersBuffer,
                frame.hdrPresentationParametersBuffer
            ]

            // All three mutable buffers for each slot are queue-wide frame
            // residents and remain separate from immutable model allocations.
            // Drawable-sized HDR textures instead use their own command-local
            // residency sets and therefore do not inflate this count.
            for allocation in frameAllocations {
                #expect(
                    store.residency.frameResources.containsAllocation(
                        allocation
                    )
                )
                #expect(
                    !store.residency.staticAssets.containsAllocation(allocation)
                )
            }
        }
    }
}
