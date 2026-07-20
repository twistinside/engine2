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

    private var shaderLibraries: [
        MetalShaderLibraryID: any MTLLibrary
    ] = [:]

    private var renderPipelineStates: [
        MetalRenderPipelineID: any MTLRenderPipelineState
    ] = [:]

    private var depthStencilStates: [
        MetalDepthStencilStateID: any MTLDepthStencilState
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
        try loadShaderLibrary(.engine)
        try loadRenderPipeline(.modelSurface)
        try loadRenderPipeline(.modelNormalDiagnostic)
        try loadDepthStencilState(.opaque)
        try loadArgumentTable(.model)
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

    /// Loads the shader library defined by a closed Render Runtime identity.
    @discardableResult
    private func loadShaderLibrary(
        _ id: MetalShaderLibraryID
    ) throws -> any MTLLibrary {
        if let existingLibrary = shaderLibraries[id] {
            return existingLibrary
        }

        let library: any MTLLibrary

        switch id {
        case .engine:
            guard let defaultLibrary = device.makeDefaultLibrary() else {
                throw MetalResourceStoreError.missingDefaultShaderLibrary
            }
            library = defaultLibrary
        }

        shaderLibraries[id] = library
        return library
    }

    /// Compiles the Metal 4 render pipeline defined by a closed identity.
    @discardableResult
    private func loadRenderPipeline(
        _ id: MetalRenderPipelineID
    ) throws -> any MTLRenderPipelineState {
        if let existingState = renderPipelineStates[id] {
            return existingState
        }

        let fragmentFunctionName: String
        let pipelineLabel: String

        switch id {
        case .modelSurface:
            fragmentFunctionName = "modelFragment"
            pipelineLabel = "USD Model Surface Pipeline"

        case .modelNormalDiagnostic:
            fragmentFunctionName = "modelNormalDiagnosticFragment"
            pipelineLabel = "USD Model Normal Diagnostic Pipeline"
        }

        let library = try shaderLibrary(for: .engine)
        let vertexFunction = MTL4LibraryFunctionDescriptor()
        vertexFunction.library = library
        // Metal identifies shader entry points by their source names, so this
        // string deliberately matches the function in ModelShaders.metal.
        vertexFunction.name = "modelVertex"

        let fragmentFunction = MTL4LibraryFunctionDescriptor()
        fragmentFunction.library = library
        fragmentFunction.name = fragmentFunctionName

        let descriptor = MTL4RenderPipelineDescriptor()
        descriptor.label = pipelineLabel
        descriptor.vertexFunctionDescriptor = vertexFunction
        descriptor.fragmentFunctionDescriptor = fragmentFunction
        descriptor.rasterSampleCount = 1
        descriptor.colorAttachments[0].pixelFormat = MetalRenderer.colorPixelFormat

        let state = try compiler.makeRenderPipelineState(
            descriptor: descriptor
        )

        renderPipelineStates[id] = state
        return state
    }

    /// Creates the immutable depth-stencil state defined by a closed identity.
    @discardableResult
    private func loadDepthStencilState(
        _ id: MetalDepthStencilStateID
    ) throws -> any MTLDepthStencilState {
        if let existingState = depthStencilStates[id] {
            return existingState
        }

        let descriptor = Self.makeDepthStencilDescriptor(for: id)

        guard let state = device.makeDepthStencilState(
            descriptor: descriptor
        ) else {
            throw MetalResourceStoreError.missingDepthStencilState(id)
        }

        depthStencilStates[id] = state
        return state
    }

    /// Builds the inspectable descriptor behind a cached depth-stencil state.
    ///
    /// `MTLDepthStencilState` intentionally does not expose the descriptor used
    /// to create it. Keeping this deterministic factory separate lets tests lock
    /// the ordinary opaque-depth convention without duplicating that policy.
    static func makeDepthStencilDescriptor(
        for id: MetalDepthStencilStateID
    ) -> MTLDepthStencilDescriptor {
        let descriptor = MTLDepthStencilDescriptor()

        switch id {
        case .opaque:
            descriptor.label = "Opaque Depth"
            descriptor.depthCompareFunction = .less
            descriptor.isDepthWriteEnabled = true
        }

        return descriptor
    }

    /// Creates the Metal 4 argument table defined by a closed identity.
    @discardableResult
    private func loadArgumentTable(
        _ id: MetalArgumentTableID
    ) throws -> any MTL4ArgumentTable {
        if let existingTable = argumentTables[id] {
            return existingTable
        }

        let descriptor = MTL4ArgumentTableDescriptor()

        switch id {
        case .model:
            descriptor.label = "USD Mesh Argument Table"
            descriptor.maxBufferBindCount = 2
        }

        let table = try device.makeArgumentTable(descriptor: descriptor)

        argumentTables[id] = table
        return table
    }

    /// Creates a fixed ring of per-frame allocators and mutable buffers.
    ///
    /// Separate resources let the CPU encode a later frame while the GPU still
    /// consumes an earlier one without resetting command memory or overwriting
    /// instance data in use. The bounded ring applies back pressure rather than
    /// allocating an unbounded stream of transient frame resources.
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
