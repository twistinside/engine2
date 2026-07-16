//
//  MetalResourceStore.swift
//  Engine2
//
//  Created by Codex on 7/15/26.
//

import Foundation
import Metal

/// Device-scoped owner for long-lived Metal backend objects.
///
/// The store is private infrastructure inside a Render Runtime. Game Content
/// supplies backend-neutral asset references, while this object resolves and
/// retains the corresponding device objects for exactly one `MTLDevice`.
@MainActor
final class MetalResourceStore {
    /// The root of every resource in this store. A different device requires a
    /// different store because Metal objects cannot move between devices.
    let device: any MTLDevice

    /// Metal 4 compiler used for pipeline creation and future archive-backed
    /// compilation. Pipeline compilation is kept out of the draw path.
    let compiler: any MTL4Compiler

    /// Metal 4 queue through which the renderer submits reusable command
    /// buffers and on which the store registers residency sets.
    let commandQueue: any MTL4CommandQueue

    /// Residency organization for allocations retained by this store.
    let residency: MetalResidencyManager

    /// Fixed ring of allocator/buffer pairs used by the renderer.
    private(set) var frames: [FrameResources] = []

    private var shaderLibrarySources: [
        MetalShaderLibraryID: MetalShaderLibrarySource
    ] = [:]
    private var shaderLibraries: [
        MetalShaderLibraryID: any MTLLibrary
    ] = [:]

    private var renderPipelineRecipes: [
        MetalRenderPipelineID: MetalRenderPipelineRecipe
    ] = [:]
    private var renderPipelineStates: [
        MetalRenderPipelineID: any MTLRenderPipelineState
    ] = [:]

    private var depthStencilRecipes: [
        MetalDepthStencilStateID: MetalDepthStencilStateRecipe
    ] = [:]
    private var depthStencilStates: [
        MetalDepthStencilStateID: any MTLDepthStencilState
    ] = [:]

    private var argumentTableRecipes: [
        MetalArgumentTableID: MetalArgumentTableRecipe
    ] = [:]
    private var argumentTables: [
        MetalArgumentTableID: any MTL4ArgumentTable
    ] = [:]

    private var models: [MeshID: USDRenderModel] = [:]

    /// Selects the system's default Metal device and creates a complete store
    /// containing the renderer's required built-in resources.
    convenience init(
        renderAssetCatalog: RenderAssetCatalog,
        frameCount: Int = MetalRenderer.maximumFramesInFlight
    ) throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw MetalResourceStoreError.missingDevice
        }

        try self.init(
            device: device,
            renderAssetCatalog: renderAssetCatalog,
            frameCount: frameCount
        )
    }

    /// Creates a resource store for an explicitly selected device.
    init(
        device: any MTLDevice,
        renderAssetCatalog: RenderAssetCatalog,
        frameCount: Int = MetalRenderer.maximumFramesInFlight
    ) throws {
        guard frameCount > 0 else {
            throw MetalResourceStoreError.invalidFrameCount(frameCount)
        }

        guard let commandQueue = device.makeMTL4CommandQueue() else {
            throw MetalResourceStoreError.missingCommandQueue
        }

        let compilerDescriptor = MTL4CompilerDescriptor()
        compilerDescriptor.label = "Engine2 Render Compiler"
        let compiler = try device.makeCompiler(descriptor: compilerDescriptor)

        let residency = try MetalResidencyManager(
            device: device,
            commandQueue: commandQueue,
            staticAssetCapacity: max(renderAssetCatalog.models.count * 4, 1),
            frameResourceCapacity: frameCount
        )

        self.device = device
        self.compiler = compiler
        self.commandQueue = commandQueue
        self.residency = residency

        // Build the small required set eagerly so frame encoding performs only
        // deterministic dictionary lookup and never triggers compilation.
        try makeFrameResources(count: frameCount)
        try loadShaderLibrary(.engine, from: .defaultLibrary)
        try loadRenderPipeline(
            .model,
            recipe: MetalRenderPipelineRecipe(
                label: "USD Model Pipeline",
                shaderLibraryID: .engine,
                vertexFunctionName: "modelVertex",
                fragmentFunctionName: "modelFragment",
                colorPixelFormat: MetalRenderer.colorPixelFormat
            )
        )
        try loadDepthStencilState(
            .disabled,
            recipe: MetalDepthStencilStateRecipe(
                label: "Depth Disabled",
                depthCompareFunction: .always,
                isDepthWriteEnabled: false
            )
        )
        try loadArgumentTable(
            .model,
            recipe: MetalArgumentTableRecipe(
                label: "USD Mesh Argument Table",
                maximumBufferBindingCount: 2
            )
        )
        try loadModels(from: renderAssetCatalog)
    }

    /// Returns a previously loaded shader library.
    func shaderLibrary(
        for id: MetalShaderLibraryID
    ) throws -> any MTLLibrary {
        guard let library = shaderLibraries[id] else {
            throw MetalResourceStoreError.missingShaderLibrary(id)
        }

        return library
    }

    /// Returns a pipeline that was compiled before frame encoding began.
    func renderPipelineState(
        for id: MetalRenderPipelineID
    ) throws -> any MTLRenderPipelineState {
        guard let state = renderPipelineStates[id] else {
            throw MetalResourceStoreError.missingRenderPipeline(id)
        }

        return state
    }

    /// Returns an immutable depth-stencil state by backend identity.
    func depthStencilState(
        for id: MetalDepthStencilStateID
    ) throws -> any MTLDepthStencilState {
        guard let state = depthStencilStates[id] else {
            throw MetalResourceStoreError.missingDepthStencilState(id)
        }

        return state
    }

    /// Returns a Metal 4 resource-binding table by backend identity.
    func argumentTable(
        for id: MetalArgumentTableID
    ) throws -> any MTL4ArgumentTable {
        guard let table = argumentTables[id] else {
            throw MetalResourceStoreError.missingArgumentTable(id)
        }

        return table
    }

    /// Resolves an abstract snapshot mesh identity to a retained backend model.
    func model(for id: MeshID) -> USDRenderModel? {
        models[id]
    }

    /// Loads a shader library once and rejects attempts to reuse an identity
    /// for a different source.
    @discardableResult
    func loadShaderLibrary(
        _ id: MetalShaderLibraryID,
        from source: MetalShaderLibrarySource
    ) throws -> any MTLLibrary {
        if let existingSource = shaderLibrarySources[id] {
            guard existingSource == source,
                  let existingLibrary = shaderLibraries[id]
            else {
                throw MetalResourceStoreError.conflictingDefinition(id.rawValue)
            }

            return existingLibrary
        }

        let library: any MTLLibrary

        switch source {
        case .defaultLibrary:
            guard let defaultLibrary = device.makeDefaultLibrary() else {
                throw MetalResourceStoreError.missingDefaultShaderLibrary
            }
            library = defaultLibrary

        case let .bundled(resourceName, fileExtension):
            guard let url = Bundle.main.url(
                forResource: resourceName,
                withExtension: fileExtension
            ) else {
                throw MetalResourceStoreError.missingBundledShaderLibrary(
                    resourceName
                )
            }

            library = try device.makeLibrary(URL: url)
        }

        shaderLibrarySources[id] = source
        shaderLibraries[id] = library
        return library
    }

    /// Compiles a Metal 4 render pipeline once and stores its recipe alongside
    /// the result so a reused identity cannot hide incompatible state.
    @discardableResult
    func loadRenderPipeline(
        _ id: MetalRenderPipelineID,
        recipe: MetalRenderPipelineRecipe
    ) throws -> any MTLRenderPipelineState {
        if let existingRecipe = renderPipelineRecipes[id] {
            guard existingRecipe == recipe,
                  let existingState = renderPipelineStates[id]
            else {
                throw MetalResourceStoreError.conflictingDefinition(id.rawValue)
            }

            return existingState
        }

        let library = try shaderLibrary(for: recipe.shaderLibraryID)

        let vertexFunction = MTL4LibraryFunctionDescriptor()
        vertexFunction.library = library
        vertexFunction.name = recipe.vertexFunctionName

        let fragmentFunction = MTL4LibraryFunctionDescriptor()
        fragmentFunction.library = library
        fragmentFunction.name = recipe.fragmentFunctionName

        let descriptor = MTL4RenderPipelineDescriptor()
        descriptor.label = recipe.label
        descriptor.vertexFunctionDescriptor = vertexFunction
        descriptor.fragmentFunctionDescriptor = fragmentFunction
        descriptor.rasterSampleCount = recipe.rasterSampleCount
        descriptor.colorAttachments[0].pixelFormat = recipe.colorPixelFormat

        let state = try compiler.makeRenderPipelineState(
            descriptor: descriptor
        )

        renderPipelineRecipes[id] = recipe
        renderPipelineStates[id] = state
        return state
    }

    /// Creates and caches an immutable depth-stencil state.
    @discardableResult
    func loadDepthStencilState(
        _ id: MetalDepthStencilStateID,
        recipe: MetalDepthStencilStateRecipe
    ) throws -> any MTLDepthStencilState {
        if let existingRecipe = depthStencilRecipes[id] {
            guard existingRecipe == recipe,
                  let existingState = depthStencilStates[id]
            else {
                throw MetalResourceStoreError.conflictingDefinition(id.rawValue)
            }

            return existingState
        }

        let descriptor = MTLDepthStencilDescriptor()
        descriptor.label = recipe.label
        descriptor.depthCompareFunction = recipe.depthCompareFunction
        descriptor.isDepthWriteEnabled = recipe.isDepthWriteEnabled

        guard let state = device.makeDepthStencilState(
            descriptor: descriptor
        ) else {
            throw MetalResourceStoreError.missingDepthStencilState(id)
        }

        depthStencilRecipes[id] = recipe
        depthStencilStates[id] = state
        return state
    }

    /// Creates and caches a Metal 4 argument table layout.
    @discardableResult
    func loadArgumentTable(
        _ id: MetalArgumentTableID,
        recipe: MetalArgumentTableRecipe
    ) throws -> any MTL4ArgumentTable {
        if let existingRecipe = argumentTableRecipes[id] {
            guard existingRecipe == recipe,
                  let existingTable = argumentTables[id]
            else {
                throw MetalResourceStoreError.conflictingDefinition(id.rawValue)
            }

            return existingTable
        }

        let descriptor = MTL4ArgumentTableDescriptor()
        descriptor.label = recipe.label
        descriptor.maxBufferBindCount = recipe.maximumBufferBindingCount
        let table = try device.makeArgumentTable(descriptor: descriptor)

        argumentTableRecipes[id] = recipe
        argumentTables[id] = table
        return table
    }

    private func makeFrameResources(count: Int) throws {
        for _ in 0..<count {
            guard let commandAllocator = device.makeCommandAllocator(),
                  let instanceBuffer = device.makeBuffer(
                    length: MemoryLayout<GPUInstance>.stride
                        * FrameResources.maximumInstanceCount,
                    options: [.storageModeShared]
                  )
            else {
                throw MetalResourceStoreError.missingFrameResource
            }

            residency.addFrameAllocation(instanceBuffer)
            frames.append(
                FrameResources(
                    commandAllocator: commandAllocator,
                    instanceBuffer: instanceBuffer
                )
            )
        }

        // One commit makes every buffer in the completed frame ring visible to
        // queue submissions that reference the frame residency set.
        residency.commitFrameResources()
    }

    private func loadModels(from catalog: RenderAssetCatalog) throws {
        let loadedModels = try USDRenderModel.load(
            catalog: catalog,
            device: device
        )

        for (meshID, model) in loadedModels {
            models[meshID] = model

            for allocation in model.allocations {
                residency.addStaticAllocation(allocation)
            }
        }

        // Apply the full initial asset batch together. Later streaming can use
        // the same add/commit boundary without changing snapshot contracts.
        residency.commitStaticAssets()
    }
}

enum MetalResourceStoreError: Error, Equatable {
    case missingDevice
    case missingCommandQueue
    case invalidFrameCount(Int)
    case missingDefaultShaderLibrary
    case missingBundledShaderLibrary(String)
    case missingShaderLibrary(MetalShaderLibraryID)
    case missingRenderPipeline(MetalRenderPipelineID)
    case missingDepthStencilState(MetalDepthStencilStateID)
    case missingArgumentTable(MetalArgumentTableID)
    case missingFrameResource
    case conflictingDefinition(String)
}
