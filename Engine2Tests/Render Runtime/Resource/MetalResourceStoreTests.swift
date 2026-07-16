//
//  MetalResourceStoreTests.swift
//  Engine2Tests
//
//  Created by Codex on 7/15/26.
//

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
        let pipeline = try store.renderPipelineState(for: .model)
        let depthStencil = try store.depthStencilState(for: .disabled)
        let argumentTable = try store.argumentTable(for: .model)

        #expect(store.device.registryID == device.registryID)
        #expect(store.compiler.device.registryID == device.registryID)
        #expect(library.functionNames.contains("modelVertex"))
        #expect(library.functionNames.contains("modelFragment"))
        #expect(pipeline.label == "USD Model Pipeline")
        #expect(depthStencil.label == "Depth Disabled")
        #expect(argumentTable.label == "USD Mesh Argument Table")
    }

    @MainActor
    @Test func repeatedDefinitionReturnsTheRetainedResource() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let store = try MetalResourceStore(
            device: device,
            renderAssetCatalog: RenderAssetCatalog(models: [:])
        )

        let first = try store.loadShaderLibrary(.engine, from: .defaultLibrary)
        let second = try store.loadShaderLibrary(.engine, from: .defaultLibrary)

        #expect(first as AnyObject === second as AnyObject)
    }

    @MainActor
    @Test func reusedIdentityRejectsAConflictingDefinition() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let store = try MetalResourceStore(
            device: device,
            renderAssetCatalog: RenderAssetCatalog(models: [:])
        )

        #expect(
            throws: MetalResourceStoreError.conflictingDefinition(
                MetalShaderLibraryID.engine.rawValue
            )
        ) {
            try store.loadShaderLibrary(
                .engine,
                from: .bundled(
                    resourceName: "AnotherLibrary",
                    fileExtension: "metallib"
                )
            )
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
